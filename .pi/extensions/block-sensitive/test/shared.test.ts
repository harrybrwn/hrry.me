import { describe, expect, it } from "vitest";
import {
	RULES,
	SOURCE,
	blockReason,
	isBareProtectedName,
	looksLikePath,
	matchPath,
	matchGlob,
} from "../shared.ts";

const cwd = "/repo";

describe("RULES", () => {
	it("has a unique id per rule", () => {
		const ids = RULES.map((rule) => rule.id);
		expect(new Set(ids).size).toBe(ids.length);
	});

	it("matches at least one of basename or path", () => {
		for (const rule of RULES) {
			expect(typeof rule.match === "function" || typeof rule.pathMatch === "function", rule.id).toBe(true);
		}
	});

	it("only opts extension-less names into exact matching", () => {
		for (const rule of RULES) {
			for (const name of rule.exactNames ?? []) {
				expect(name).not.toMatch(/[./]/);
				expect(rule.match?.(name)).toBe(true);
			}
		}
	});
});

describe("matchPath", () => {
	const blocked: Array<[string, string]> = [
		[".env", ".env"],
		["prod.env", ".env"],
		["./prod.env", ".env"],
		["config/.env", ".env"],
		["/etc/app/secrets.env", ".env"],
		["../.env", ".env"],
		["./.env/../.env", ".env"],
		[".ENV", ".env"],
		["server.crt", ".crt"],
		["SERVER.CRT", ".crt"],
		["tls/server.key", ".key"],
		["private.KEY", ".key"],
		["prod.tfvars", ".tfvars"],
		["terraform.tfstate", ".tfstate"],
		["terraform.tfstate.backup", ".tfstate"],
		["environments/dev.tfstate.d", ".tfstate"],
		["db-password.yaml", "password"],
		["Passwords.txt", "password"],
		["db_password.txt", "password"],
		["htpasswd", "htpasswd"],
		["/etc/nginx/HTPASSWD", "htpasswd"],
		// directory-scoped: json under config/k8s, at any depth
		["config/k8s/app/minio/bucket-policies/static-files.json", "config/k8s/*.json"],
		["./config/k8s/stg/files/clients/outline.json", "config/k8s/*.json"],
		["config/k8s/dev/filestash-config.json", "config/k8s/*.json"],
		["/home/dev/web/hrry.me/config/k8s/app/minio/bucket-policies/outline-bucket-access.json", "config/k8s/*.json"],
	];

	const allowed = [
		".env.local",
		".envrc",
		"environment.ts",
		"env.md",
		"notes.txt",
		"keyboard.md",
		"monkey.txt",
		"server.pem",
		"config.yaml",
		"htpasswd.example",
		"my-htpasswd",
		"README.md",
	];

	it.each(blocked)("blocks %s with rule %s", (target, ruleId) => {
		expect(matchPath(target, cwd)?.id).toBe(ruleId);
	});

	it.each(allowed)("allows %s", (target) => {
		expect(matchPath(target, cwd)).toBeUndefined();
	});

	it("ignores missing paths", () => {
		expect(matchPath(undefined, cwd)).toBeUndefined();
		expect(matchPath("", cwd)).toBeUndefined();
	});

	it("resolves relative paths against the session cwd", () => {
		expect(matchPath(".env", "/repo/sub")?.id).toBe(".env");
		// Basename-only matching: the directory name does not matter.
		expect(matchPath("terraform.tfstate.d/some-file", cwd)).toBeUndefined();
	});
});

describe("matchGlob", () => {
	const blocked: Array<[string, string]> = [
		["*.env", ".env"],
		["**/*.env", ".env"],
		[".env", ".env"],
		["**/.env", ".env"],
		["*.ENV", ".env"],
		["*.crt", ".crt"],
		["**/*.key", ".key"],
		["*.tfvars", ".tfvars"],
		["*.tfstate*", ".tfstate"],
		["*password*", "password"],
		["passwords.*", "password"],
		["htpasswd", "htpasswd"],
		["config/k8s/**/*.json", "config/k8s/*.json"],
		["config/k8s/app/**/*.json", "config/k8s/*.json"],
	];

	const allowed = ["*", "**/*.ts", "*.ts", "*.txt", "*.json", "env.*", "htpasswd.example", "src/**/*.go"];

	it.each(blocked)("blocks %s with rule %s", (pattern, ruleId) => {
		expect(matchGlob(pattern)?.id).toBe(ruleId);
	});

	it.each(allowed)("allows %s", (pattern) => {
		expect(matchGlob(pattern)).toBeUndefined();
	});

	it("ignores missing patterns", () => {
		expect(matchGlob(undefined)).toBeUndefined();
		expect(matchGlob("")).toBeUndefined();
	});

	it("keeps regex metacharacters literal", () => {
		// `a+b.env` names one specific file, it is not a glob for every `.env`.
		// (reading it directly is still blocked by `matchBasename`)
		expect(matchGlob("a+b.env")).toBeUndefined();
		expect(matchPath("a+b.env", cwd)?.id).toBe(".env");
		// An unescaped `+` would behave as a quantifier and could over-match.
		expect(matchGlob("x+.env")).toBeUndefined();
		expect(matchGlob("*.env")?.id).toBe(".env");
	});
});

describe("matchPath — directory-scoped rules", () => {
	const k8sJson = [
		"config/k8s/app/minio/bucket-policies/static-files.json",
		"config/k8s/stg/files/clients/grafana.json",
		"config/k8s/dev/files/clients/outline.json",
		"./config/k8s/dev/filestash-config.json",
	];

	it.each(k8sJson)("blocks %s from the repo root", (target) => {
		expect(matchPath(target, "/home/dev/web/hrry.me")?.id).toBe("config/k8s/*.json");
	});

	it.each(k8sJson)("blocks %s from a nested cwd", (target) => {
		expect(matchPath(target, "/home/dev/web/hrry.me/config")?.id).toBe("config/k8s/*.json");
	});

	it("blocks the same file when the session cwd is inside config/k8s", () => {
		expect(matchPath("app/minio/bucket-policies/static-files.json", "/repo/config/k8s")?.id).toBe(
			"config/k8s/*.json",
		);
		expect(matchPath("../dev/filestash-config.json", "/repo/config/k8s/stg")?.id).toBe("config/k8s/*.json");
	});

	it("leaves json outside config/k8s blocked-free", () => {
		for (const target of ["package.json", "config/settings.json", "src/data.json", "config/k8s/prod.yaml"]) {
			expect(matchPath(target, "/repo"), target).toBeUndefined();
		}
	});

	it("does not leak to sibling directories or extensions", () => {
		expect(matchPath("config/settings.json", "/repo")).toBeUndefined();
		expect(matchPath("k8s/static-files.json", "/repo")).toBeUndefined();
		expect(matchPath("config/k8s/prod.yaml", "/repo")).toBeUndefined();
		expect(matchPath("config/k8s/Makefile", "/repo")).toBeUndefined();
		expect(matchPath("config/k8s/app/minio/bucket-policies", "/repo")).toBeUndefined();
		// `k8sfoo` is not the k8s directory
		expect(matchPath("config/k8sfoo/x.json", "/repo")).toBeUndefined();
	});
});

describe("looksLikePath", () => {
	it("accepts paths and protected extension-less names", () => {
		for (const token of ["db-password.yaml", "notes.txt", "/etc/passwd", "./x", "htpasswd", "HTPASSWD"]) {
			expect(looksLikePath(token), token).toBe(true);
		}
	});

	it("rejects prose and search patterns", () => {
		for (const token of ["password", "passwords", "secret", "-i", "README"]) {
			expect(looksLikePath(token), token).toBe(false);
		}
	});
});

describe("isBareProtectedName", () => {
	it("matches only exact extension-less protected names", () => {
		expect(isBareProtectedName("htpasswd")).toBe(true);
		expect(isBareProtectedName("HTPASSWD")).toBe(true);
		expect(isBareProtectedName("htpasswd.example")).toBe(false);
		expect(isBareProtectedName("password")).toBe(false);
	});
});

describe("blockReason", () => {
	it("names the extension, the rule and the match", () => {
		const rule = RULES.find((candidate) => candidate.id === ".env")!;
		const reason = blockReason(rule, "/repo/.env");

		expect(reason).toContain(SOURCE);
		expect(reason).toContain(rule.id);
		expect(reason).toContain('"/repo/.env"');
		expect(reason).toMatch(/ask the user/i);
	});
});
