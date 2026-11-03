import { describe, expect, it } from "vitest";
import type { ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { inspectToolCall } from "../reads.ts";

const cwd = "/repo";

function event(toolName: string, input: Record<string, unknown>): ToolCallEvent {
	return { toolName, toolCallId: "test-call", input } as unknown as ToolCallEvent;
}

const blocked: Array<[string, Record<string, unknown>]> = [
	["read", { path: "/repo/.env" }],
	["read", { path: "prod.env" }],
	["read", { path: "/repo/tls/server.key" }],
	["read", { path: "/repo/server.crt" }],
	["read", { path: "/repo/infra/prod.tfvars" }],
	["read", { path: "/repo/terraform.tfstate.backup" }],
	["read", { path: "/repo/Passwords.txt" }],
	["read", { path: "/repo/htpasswd" }],
	["ls", { path: "/repo/.env" }],
	["grep", { pattern: "SECRET", path: "/repo/.env" }],
	["grep", { pattern: "SECRET", glob: "*.env" }],
	["grep", { pattern: "KEY", glob: "**/*.key" }],
	["grep", { pattern: "x", glob: "*password*" }],
	["find", { pattern: "**/*.tfstate*" }],
	["find", { pattern: "*.crt" }],
	["find", { pattern: "htpasswd" }],
	["find", { pattern: "*", path: "/repo/prod.tfvars" }],
	// directory-scoped: json under config/k8s
	["read", { path: "/repo/config/k8s/app/minio/bucket-policies/static-files.json" }],
	["read", { path: "config/k8s/dev/filestash-config.json" }],
	["grep", { pattern: "x", path: "/repo/config/k8s/stg/files/clients/outline.json" }],
	["find", { pattern: "config/k8s/**/*.json" }],
];

const allowed: Array<[string, Record<string, unknown>]> = [
	["read", { path: "/repo/notes.txt" }],
	["read", { path: "/repo/.env.local" }],
	["read", { path: "/repo/README.md" }],
	["ls", { path: "/repo" }],
	["ls", {}],
	["grep", { pattern: "password", path: "/repo/src" }],
	["grep", { pattern: "x", glob: "*.ts" }],
	["find", { pattern: "*.ts" }],
	["find", { pattern: "*" }],
	["find", { pattern: "**/*.json" }],
	// Not in scope: writes are deliberately untouched, and other tools are ignored.
	["write", { path: "/repo/.env", content: "SECRET=1" }],
	["edit", { path: "/repo/.env", edits: [] }],
	["webfetch", { url: "https://example.com/.env" }],
	// json is only protected inside config/k8s
	["read", { path: "/repo/config/settings.json" }],
	["read", { path: "/repo/package.json" }],
	["read", { path: "/repo/config/k8s/prod.yaml" }],
	["grep", { pattern: "x", glob: "*.json" }],
	["find", { pattern: "*.json" }],
	["todo", { action: "list" }],
];

describe("inspectToolCall", () => {
	it.each(blocked)("blocks %s(%o)", (toolName, input) => {
		expect(inspectToolCall(event(toolName, input), cwd)).toBeDefined();
	});

	it.each(allowed)("allows %s(%o)", (toolName, input) => {
		expect(inspectToolCall(event(toolName, input), cwd)).toBeUndefined();
	});

	it("reports the path it matched", () => {
		const hit = inspectToolCall(event("read", { path: "/repo/infra/prod.tfvars" }), cwd);
		expect(hit?.rule.id).toBe(".tfvars");
		expect(hit?.matched).toBe("/repo/infra/prod.tfvars");
	});

	it("reports globs with their field name", () => {
		expect(inspectToolCall(event("grep", { glob: "*.env" }), cwd)?.matched).toBe("glob *.env");
		expect(inspectToolCall(event("find", { pattern: "*.env" }), cwd)?.matched).toBe("pattern *.env");
	});

	it("reports the k8s json rule for nested json", () => {
		const hit = inspectToolCall(
			event("read", { path: "/repo/config/k8s/app/minio/bucket-policies/static-files.json" }),
			cwd,
		);
		expect(hit?.rule.id).toBe("config/k8s/*.json");
	});

	it("prefers a blocked path over a harmless glob", () => {
		const hit = inspectToolCall(event("grep", { path: "/repo/.env", glob: "*.ts" }), cwd);
		expect(hit?.rule.id).toBe(".env");
		expect(hit?.matched).toBe("/repo/.env");
	});

	it("resolves paths against the given cwd", () => {
		expect(inspectToolCall(event("read", { path: ".env" }), "/repo/sub")?.rule.id).toBe(".env");
		expect(inspectToolCall(event("read", { path: "notes.txt" }), cwd)).toBeUndefined();
	});
});
