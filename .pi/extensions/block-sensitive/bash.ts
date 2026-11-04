/**
 * Bash layer of `block-sensitive`.
 *
 * Parses the `bash` tool's command with tree-sitter-bash and inspects every
 * `command` node (pipelines, `&&`, loops, `$(...)` substitutions and subshells
 * included), plus `<` input redirects.
 *
 * Judged conservatively, because false positives block real work:
 *
 *   - Leading assignments and wrappers (`sudo -E`, `env FOO=1`, `xargs -0`,
 *     `timeout 30`, `nice -n 10`, ...) are peeled off to find the real command.
 *   - Only arguments of file-reading commands (`cat`, `grep`, `jq`, `openssl`,
 *     `source`, `python`, `cp`, `curl`, `docker`, `terraform`, ...) are checked,
 *     so `git commit -m "fix password reset"` and `grep password notes.txt` pass.
 *   - `bash -c '...'`, `sh -c`, `eval`, `su -c` bodies are re-parsed (depth 3).
 *   - A token has to look like a path (`.`/`/` or an extension-less protected name),
 *     which is what keeps prose and search patterns from matching.
 *   - Arguments that *exclude* files are not reads, but only where the command
 *     says so: `COMMAND_FLAG_RULES` lists, per command, the flags whose value is
 *     a negatable glob (`rg --glob '!*.tfstate*'`) or an exclude list
 *     (`grep --exclude '*.env'`).
 *
 * Known gaps: `find -exec cat {} +`, tokens that only resolve at runtime (`cat $FILE`).
 */

import path from "node:path";
import Parser from "tree-sitter";
import Bash from "tree-sitter-bash";
import { looksLikePath, matchGlob, matchPath, type Hit, type Rule } from "./shared.ts";

/** How deep `bash -c "bash -c ..."` nesting is followed. */
const MAX_NESTING = 3;

/** Commands whose arguments are file contents being read, copied, or shipped off. */
const READERS = new Set([
	// plain reading
	"cat", "tac", "less", "more", "most", "head", "tail", "nl", "od", "xxd", "hexdump", "strings",
	"base64", "base32", "uudecode", "rev", "fold", "expand", "unexpand",
	// searching
	"grep", "egrep", "fgrep", "rg", "ag", "ack", "ugrep", "awk", "gawk", "mawk", "sed", "perl",
	// processing
	"sort", "uniq", "cut", "tr", "wc", "diff", "cmp", "comm", "join", "paste", "jq", "yq", "xmllint",
	// key/cert/secret tooling
	"openssl", "gpg", "ssh-keygen", "sops", "age", "ansible-vault", "dotenv", "dotenvx", "direnv",
	// interpreters can read any path
	"source", ".", "bash", "sh", "zsh", "dash", "ksh", "fish", "ash", "mksh", "python", "python3",
	"node", "ruby", "php",
	// copying / exfiltration
	"cp", "mv", "rsync", "scp", "sftp", "install", "ln", "tar", "zip", "unzip", "gunzip", "nc", "ncat",
	// tooling that takes a file flag
	"curl", "wget", "docker", "podman", "kubectl", "helm", "terraform", "tofu", "systemctl", "git",
]);

/** Commands that just run another command; stripped before reading arguments. */
const WRAPPERS = new Set([
	"sudo", "doas", "env", "command", "exec", "time", "nice", "nohup", "stdbuf", "builtin",
	"timeout", "xargs", "watch", "ionice", "setsid", "fakeroot", "unbuffer", "busybox", "flock",
	"taskset", "chroot",
]);

/** Wrapper flags that consume the following token, so it is not mistaken for the command. */
const WRAPPER_VALUE_FLAGS: Record<string, string[]> = {
	sudo: ["-u", "-g", "-p", "-C", "-U", "-h", "-r", "-t", "-D", "-R", "-T"],
	doas: ["-u", "-C"],
	env: ["-u", "-C", "--unset", "--chdir"],
	xargs: ["-n", "-I", "-P", "-d", "-L", "-s", "-E", "-a", "--max-args", "--replace", "--delimiter", "--max-procs", "--arg-file"],
	nice: ["-n", "--adjustment"],
	timeout: ["-s", "-k", "--signal", "--kill-after"],
	watch: ["-n", "-d", "--interval", "--differences"],
	ionice: ["-c", "-n", "-p", "--class", "--classdata"],
	taskset: ["-c", "-p"],
	flock: ["-w", "-E", "--timeout", "--conflict-exit-code"],
	chroot: ["--userspec", "--groups"],
};

/**
 * `su` / `runuser` are intentionally *not* wrappers: their `-c` value is a command
 * string, which `nestedCommand` parses again. Stripping them as wrappers would
 * swallow that string instead.
 */

/** Shells whose `-c STRING` body is parsed again. */
const SHELLS = new Set(["bash", "sh", "zsh", "dash", "ksh", "fish", "ash", "mksh", "eval"]);

interface SyntaxNode {
	type: string;
	text: string;
	namedChildren: SyntaxNode[];
	children: SyntaxNode[];
	childForFieldName(name: string): SyntaxNode | null;
	childrenForFieldName(name: string): SyntaxNode[];
}

let parser: Parser | undefined;

function getParser(): Parser {
	if (!parser) {
		parser = new Parser();
		parser.setLanguage(Bash);
	}
	return parser;
}

/** Drop one layer of matching quotes, as tree-sitter hands back raw source text. */
function unquote(token: string): string {
	const trimmed = token.trim();
	if (trimmed.length >= 2) {
		const first = trimmed[0];
		if ((first === '"' || first === "'") && trimmed[trimmed.length - 1] === first) {
			return trimmed.slice(1, -1);
		}
	}
	return trimmed;
}

const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;

/**
 * Command- and flag-specific argument rules.
 *
 * Every argument of a reader command is normally judged as a possible path. Some
 * flags do not take paths though: their value is a glob, and some of those globs
 * *exclude* files (`rg --glob '!*.tfstate*'`). Such a value is not a read and
 * must be left alone.
 *
 * Scope is deliberately narrow: a rule fires only when the resolved command
 * matches AND the token is the value of the listed flag. A bare `!pattern`
 * argument, the same pattern passed to another command, or the same flag on a
 * different command is still checked normally. Add an entry here when another
 * command grows a flag like this — nothing else has to change.
 */
interface FlagRule {
	/** Gitignore-style glob where a leading `!` negates, i.e. excludes, matches. */
	negatableGlob?: boolean;
	/** Value names files to exclude, so it is never a read. */
	excludes?: boolean;
}

const GREP_EXCLUDES: Record<string, FlagRule> = {
	"--exclude": { excludes: true },
	"--exclude-dir": { excludes: true },
};

const COMMAND_FLAG_RULES: Record<string, Record<string, FlagRule>> = {
	// ripgrep: `--glob '!*.tfstate*'` tells rg to skip the files we protect.
	rg: {
		"--glob": { negatableGlob: true },
		"-g": { negatableGlob: true },
		"--pre-glob": { negatableGlob: true },
	},
	// grep: `--exclude '*.env'` / `--exclude-dir` name what to skip.
	grep: GREP_EXCLUDES,
	egrep: GREP_EXCLUDES,
	fgrep: GREP_EXCLUDES,
};

/** The rule for `flag` on `command`, if the table declares one. */
function flagRuleFor(command: string, flag: string): FlagRule | undefined {
	if (!Object.hasOwn(COMMAND_FLAG_RULES, command)) return undefined;

	const table = COMMAND_FLAG_RULES[command];
	return Object.hasOwn(table, flag) ? table[flag] : undefined;
}

/** The rule hit by one command argument, if any. */
function checkToken(raw: string, cwd: string): Rule | undefined {
	let token = unquote(raw);
	if (!token || token === "-" || token === "--") return undefined;

	// `curl -d @.env`, `--env-file .env`, `-f=.env`.
	if (token.startsWith("@")) token = token.slice(1);
	if (token.startsWith("-")) {
		const eq = token.indexOf("=");
		if (eq < 0) return undefined;
		token = token.slice(eq + 1);
		if (token.startsWith("@")) token = token.slice(1);
	}

	if (!token || ASSIGNMENT.test(token)) return undefined;
	if (!looksLikePath(token)) return undefined;

	return matchPath(token, cwd) ?? matchGlob(token);
}

/** True when a flag value is a pattern that excludes files instead of reading them. */
function isExcludedValue(rule: FlagRule, value: string): boolean {
	if (rule.excludes) return true;
	return Boolean(rule.negatableGlob) && unquote(value).startsWith("!");
}

/**
 * First offending argument in the list.
 *
 * `command` is only used to look up `COMMAND_FLAG_RULES`; the walk itself is
 * generic. A flag declared there owns the token after it (or the text after
 * `=`), so that value is judged once, with the flag's rule applied.
 */
function checkArguments(command: string, args: string[], cwd: string): Rule | undefined {
	for (let i = 0; i < args.length; i++) {
		const raw = args[i];
		const eq = raw.startsWith("-") ? raw.indexOf("=") : -1;

		if (eq > 0) {
			// `rg --glob=!*.env`, `grep --exclude=*.env`: value attached to the flag.
			const attached = flagRuleFor(command, raw.slice(0, eq));
			if (attached && isExcludedValue(attached, raw.slice(eq + 1))) continue;
		} else if (raw.startsWith("-")) {
			// `rg --glob '!*.tfstate*'`, `grep --exclude '*.env'`: consume the value so
			// it is not revisited as a bare argument below.
			const declared = flagRuleFor(command, raw);
			if (declared) {
				const value = args[++i];
				if (value === undefined || isExcludedValue(declared, value)) continue;

				const found = checkToken(value, cwd);
				if (found) return found;
				continue;
			}
		}

		const rule = checkToken(raw, cwd);
		if (rule) return rule;
	}

	return undefined;
}

/**
 * Peel off leading assignments and wrapper commands, returning the command that
 * actually does the work (`sudo -E env A=1 xargs -0 cat x` -> `cat`).
 */
function resolveCommand(tokens: string[]): { name: string; args: string[] } | undefined {
	let i = 0;

	for (let guard = 0; i < tokens.length && guard < 32; guard++) {
		const token = tokens[i];
		if (!token) {
			i++;
			continue;
		}
		if (ASSIGNMENT.test(token) && !token.includes("/")) {
			i++;
			continue;
		}

		const name = path.basename(token);
		if (!WRAPPERS.has(name)) return { name, args: tokens.slice(i + 1) };

		i++;
		const valueFlags = new Set(WRAPPER_VALUE_FLAGS[name] ?? []);
		while (i < tokens.length) {
			const next = tokens[i];
			if (valueFlags.has(next)) {
				i += 2;
				continue;
			}
			if (ASSIGNMENT.test(next) || /^\d+(\.\d+)?s?$/.test(next)) {
				i++;
				continue;
			}
			if (next.startsWith("-")) {
				i++;
				continue;
			}
			break;
		}
	}

	return undefined;
}

/** The nested command string of `bash -c`, `eval`, `su -c`, ... if any. */
function nestedCommand(name: string, args: string[]): string | undefined {
	if (name === "eval") return args.join(" ") || undefined;

	if (SHELLS.has(name) || name === "su" || name === "runuser") {
		const index = args.findIndex((arg) => arg === "-c" || arg === "--command");
		if (index >= 0 && index + 1 < args.length) return unquote(args[index + 1]);
	}

	return undefined;
}

function checkRedirect(node: SyntaxNode, cwd: string): Rule | undefined {
	const operator = node.children.find(
		(child) => /^(>|<)/.test(child.text) && !child.type.startsWith("word"),
	);
	// Only `<` reads a file; `>` writes, `<<` is a heredoc and `<<<` is a string.
	if (operator?.text !== "<") return undefined;

	const destination = node.childForFieldName("destination");
	return destination ? checkToken(destination.text, cwd) : undefined;
}

function inspectNode(node: SyntaxNode, cwd: string, depth: number): Hit | undefined {
	if (node.type === "command") {
		const nameNode = node.childForFieldName("name");
		const args = node.childrenForFieldName("argument").map((argument) => argument.text);

		if (nameNode) {
			const command = resolveCommand([nameNode.text, ...args]);

			if (command) {
				if (READERS.has(command.name)) {
					const rule = checkArguments(command.name, command.args, cwd);
					if (rule) return { rule, matched: node.text };
				}

				if (depth < MAX_NESTING) {
					const nested = nestedCommand(command.name, command.args.map(unquote));
					if (nested) {
						const inner = inspectCommand(nested, cwd, depth + 1);
						if (inner) return inner;
					}
				}
			}
		}
	} else if (node.type === "file_redirect") {
		const rule = checkRedirect(node, cwd);
		if (rule) return { rule, matched: node.text };
	}

	for (const child of node.namedChildren) {
		const hit = inspectNode(child, cwd, depth);
		if (hit) return hit;
	}

	return undefined;
}

/** Inspect a full shell command line. */
export function inspectCommand(command: string, cwd: string, depth = 0): Hit | undefined {
	try {
		const tree = getParser().parse(command);
		return inspectNode(tree.rootNode, cwd, depth);
	} catch {
		return undefined;
	}
}
