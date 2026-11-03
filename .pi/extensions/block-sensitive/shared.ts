/**
 * Shared code for the `block-sensitive` extension.
 *
 * One rule table drives both layers (`reads.ts` for the file tools, `bash.ts` for
 * parsed shell commands):
 *
 *   - secrets   : names ending in `.env`
 *   - certs     : names ending in `.crt` or `.key`
 *   - terraform : names ending in `.tfvars`, or containing `.tfstate`
 *   - k8s       : `.json` files anywhere under `config/k8s/`
 *   - anything  : names containing "password", and files named exactly `htpasswd`
 *
 * Most rules match a *basename*. A rule may instead (or additionally) declare
 * `pathMatch`, which receives the resolved absolute path — that is how the
 * directory-scoped k8s rule stays narrow.
 *
 * This directory is loaded through `index.ts` only (Pi does not pick up sibling
 * files as separate extensions), so the other modules are plain imports.
 */

import path from "node:path";

/** Label used in block reasons. */
export const SOURCE = "block-sensitive";

export interface Rule {
	/** Short label used in notifications and block reasons. */
	id: string;
	/** True when a file's basename is protected by this rule. */
	match?: (basename: string) => boolean;
	/** True when a resolved absolute path is protected by this rule. */
	pathMatch?: (absolutePath: string) => boolean;
	/** Substrings a glob must contain before it is even considered. */
	globMarkers: string[];
	/** Names a glob has to be able to match for this rule to apply. */
	globSamples: string[];
	/**
	 * Complete basenames that are protected but contain no `.` or `/`, so token
	 * scanners (shell arguments) still treat them as file paths.
	 */
	exactNames?: string[];
}

export interface Hit {
	rule: Rule;
	matched: string;
}

export const RULES: Rule[] = [
	{
		id: ".env",
		match: (name) => /\.env$/i.test(name),
		globMarkers: [".env"],
		globSamples: [".env", "x.env"],
	},
	{
		id: ".crt",
		match: (name) => /\.crt$/i.test(name),
		globMarkers: [".crt"],
		globSamples: ["x.crt"],
	},
	{
		id: ".key",
		match: (name) => /\.key$/i.test(name),
		globMarkers: [".key"],
		globSamples: ["x.key"],
	},
	{
		id: ".tfvars",
		match: (name) => /\.tfvars$/i.test(name),
		globMarkers: [".tfvars"],
		globSamples: ["x.tfvars"],
	},
	{
		id: ".tfstate",
		match: (name) => /\.tfstate/i.test(name),
		globMarkers: [".tfstate"],
		globSamples: ["x.tfstate", "x.tfstate.backup"],
	},
	{
		// Directory-scoped: every JSON file in the k8s config tree, at any depth,
		// regardless of the session cwd. Keyed on the path so a plain `*.json`
		// elsewhere in the repo is unaffected.
		id: "config/k8s/*.json",
		pathMatch: (absolute) => /[\\/]config[\\/]k8s[\\/].*\.json$/i.test(absolute),
		globMarkers: ["config/k8s", ".json"],
		globSamples: ["x.json"],
	},
	{
		id: "password",
		match: (name) => /password/i.test(name),
		globMarkers: ["password"],
		globSamples: ["password", "x-password.txt", "passwords.json"],
	},
	{
		// Exact name only: `htpasswd`, not `htpasswd.example` or `my-htpasswd`.
		id: "htpasswd",
		match: (name) => name.toLowerCase() === "htpasswd",
		globMarkers: ["htpasswd"],
		globSamples: ["htpasswd"],
		exactNames: ["htpasswd"],
	},
];

/** The rule protecting this target, if any. Resolves `target` against `cwd`. */
export function matchPath(target: string | undefined, cwd: string): Rule | undefined {
	if (!target) return undefined;

	const absolute = path.resolve(cwd, target);
	const name = path.basename(absolute);

	return RULES.find((rule) => rule.match?.(name) || rule.pathMatch?.(absolute));
}

function globToRegExp(name: string): RegExp {
	return new RegExp(
		`^${name
			.replace(/[.+^${}()|[\]\\]/g, "\\$&")
			.replace(/\*/g, ".*")
			.replace(/\?/g, ".")}$`,
		"i",
	);
}

/**
 * The rule a glob/pattern targets, if any. The pattern must mention the rule's
 * markers (anywhere in the pattern) and its last segment must be able to match a
 * protected name, so broad patterns (a bare `*`, TypeScript globs) stay allowed.
 */
export function matchGlob(pattern: string | undefined): Rule | undefined {
	if (!pattern) return undefined;

	const name = pattern.split(/[\\/]/).filter(Boolean).pop() ?? "";
	if (!name) return undefined;

	const lower = pattern.toLowerCase();
	const regex = globToRegExp(name);

	return RULES.find(
		(rule) =>
			rule.globMarkers.every((marker) => lower.includes(marker)) &&
			rule.globSamples.some((sample) => regex.test(sample)),
	);
}

/** True for protected names that carry no `.` or `/` (`htpasswd`). */
export function isBareProtectedName(token: string): boolean {
	const lower = token.toLowerCase();
	return RULES.some((rule) => rule.exactNames?.includes(lower));
}
/** Coarse "could this be a path?" test, to avoid matching prose or search patterns. */
export function looksLikePath(token: string): boolean {
	return (
		token.includes("/") ||
		token.includes(".") ||
		// Shell globs name files too: `cat *password*`.
		/[*?[]/.test(token) ||
		isBareProtectedName(token)
	);
}

export function blockReason(rule: Rule, matched: string): string {
	return `Access to sensitive files is blocked (${SOURCE}: ${rule.id} matched "${matched}"). Do not read, search, or list them; ask the user directly if a value from that file is required.`;
}
