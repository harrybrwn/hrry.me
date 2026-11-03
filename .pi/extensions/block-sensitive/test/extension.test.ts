import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import blockSensitive from "../index.ts";
import { logPath, type BlockLogEntry } from "../log.ts";

interface Notify {
	message: string;
	level?: string;
}

const dirs: string[] = [];

function tempDir(): string {
	const dir = mkdtempSync(path.join(tmpdir(), "block-sensitive-ext-"));
	dirs.push(dir);
	return dir;
}

function readEntries(cwd: string): BlockLogEntry[] {
	if (!existsSync(logPath(cwd))) return [];
	return readFileSync(logPath(cwd), "utf8")
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line) as BlockLogEntry);
}

function setup(cwd = tempDir(), sessionId = "session-1") {
	const handlers = new Map<string, (event: unknown, ctx: unknown) => Promise<unknown> | unknown>();
	const notifications: Notify[] = [];

	const pi = {
		on: (name: string, handler: (event: unknown, ctx: unknown) => unknown) => {
			handlers.set(name, handler);
		},
	} as unknown as ExtensionAPI;

	blockSensitive(pi);

	const ctx = {
		cwd,
		hasUI: true,
		sessionManager: { getSessionId: () => sessionId },
		ui: { notify: (message: string, level?: string) => notifications.push({ message, level }) },
	};

	const run = async (event: unknown) => handlers.get("tool_call")!(event, ctx);

	return { run, notifications, handlers, cwd };
}

const toolCall = (toolName: string, input: Record<string, unknown>) => ({
	toolName,
	toolCallId: "call-1",
	input,
});

afterEach(() => {
	for (const dir of dirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

describe("block-sensitive extension", () => {
	it("registers exactly one tool_call handler", () => {
		const { handlers } = setup();
		expect([...handlers.keys()]).toEqual(["tool_call"]);
	});

	it("blocks a bash read and explains why", async () => {
		const { run, notifications, cwd } = setup();

		const result = (await run(toolCall("bash", { command: "sudo -E cat /etc/app/.env" }))) as {
			block: boolean;
			reason: string;
		};

		expect(result.block).toBe(true);
		expect(result.reason).toContain("block-sensitive");
		expect(result.reason).toContain(".env");
		expect(result.reason).toContain("cat /etc/app/.env");
		expect(notifications).toEqual([{ message: "Blocked .env access: sudo -E cat /etc/app/.env", level: "warning" }]);
		expect(readEntries(cwd)).toHaveLength(1);
	});

	it("blocks a read tool call and explains why", async () => {
		const { run, notifications } = setup();

		const result = (await run(toolCall("read", { path: "/repo/infra/prod.tfvars" }))) as {
			block: boolean;
			reason: string;
		};

		expect(result.block).toBe(true);
		expect(result.reason).toContain(".tfvars");
		expect(notifications[0]?.message).toBe("Blocked .tfvars access: /repo/infra/prod.tfvars");
	});

	it("lets harmless calls through without notifying", async () => {
		const { run, notifications, cwd } = setup();

		expect(await run(toolCall("bash", { command: "cat notes.txt" }))).toBeUndefined();
		expect(await run(toolCall("read", { path: "/repo/notes.txt" }))).toBeUndefined();
		expect(await run(toolCall("write", { path: "/repo/.env", content: "SECRET=1" }))).toBeUndefined();
		expect(notifications).toEqual([]);
		expect(readEntries(cwd)).toEqual([]);
	});

	it("ignores empty bash commands", async () => {
		const { run } = setup();
		expect(await run(toolCall("bash", { command: "" }))).toBeUndefined();
		expect(await run(toolCall("bash", { command: "   " }))).toBeUndefined();
		expect(await run(toolCall("bash", {}))).toBeUndefined();
	});

	it("truncates very long commands in the reason", async () => {
		const { run } = setup();
		const command = `echo ${"x".repeat(400)} && cat .env`;

		const result = (await run(toolCall("bash", { command }))) as { block: boolean; reason: string };
		const quoted = /matched "([^"]*)"/.exec(result.reason)?.[1] ?? "";

		expect(result.block).toBe(true);
		expect(quoted.length).toBeLessThanOrEqual(140);
		expect(quoted.endsWith("...")).toBe(true);
	});

	it("skips the UI notification when there is no UI", async () => {
		const handlers = new Map<string, (event: unknown, ctx: unknown) => unknown>();
		blockSensitive({ on: (name: string, handler: never) => handlers.set(name, handler) } as unknown as ExtensionAPI);

		const result = (await handlers.get("tool_call")!(
			toolCall("read", { path: "/repo/.env" }),
			{ cwd: tempDir(), hasUI: false, ui: { notify: () => expect.fail("notify should not be called") } },
		)) as { block: boolean };

		expect(result.block).toBe(true);
	});

	it("uses the session cwd to resolve relative paths", async () => {
		const { run } = setup("/home/dev/project");
		expect(await run(toolCall("read", { path: "notes.txt" }))).toBeUndefined();
		expect(await run(toolCall("read", { path: "secrets.env" }))).toBeDefined();
	});
});

describe("block-sensitive log", () => {
	it("records the tool, layer, rule and matched target", async () => {
		const { run, cwd } = setup();

		await run(toolCall("read", { path: "config/k8s/dev/filestash-config.json" }));
		await run(toolCall("bash", { command: "cat .env" }));

		const entries = readEntries(cwd);
		expect(entries).toHaveLength(2);
		expect(entries[0]).toMatchObject({
			tool: "read",
			layer: "file-tool",
			rule: "config/k8s/*.json",
			matched: "config/k8s/dev/filestash-config.json",
			cwd,
			sessionId: "session-1",
		});
		expect(entries[1]).toMatchObject({ tool: "bash", layer: "bash", rule: ".env", matched: "cat .env" });
		// the raw tool input is recorded as JSON, so nothing is lost
		expect(entries[1]!.input).toBe('{"command":"cat .env"}');
	});

	it("keeps one line per block and never logs allowed calls", async () => {
		const { run, cwd } = setup();

		await run(toolCall("read", { path: "/repo/.env" }));
		await run(toolCall("read", { path: "/repo/.env" }));
		await run(toolCall("read", { path: "/repo/notes.txt" }));

		expect(readEntries(cwd)).toHaveLength(2);
	});

	it("still blocks when the log cannot be written", async () => {
		const cwd = tempDir();
		// A read-only-ish cwd: `.pi` exists as a file, so the log dir cannot be created.
		writeFileSync(path.join(cwd, ".pi"), "not a directory");
		const { run } = setup(cwd);

		const result = (await run(toolCall("read", { path: "/repo/.env" }))) as { block: boolean };
		expect(result.block).toBe(true);
		expect(readEntries(cwd)).toEqual([]);
	});
});
