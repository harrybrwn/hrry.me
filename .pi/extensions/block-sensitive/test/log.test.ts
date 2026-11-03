import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { LOG_RELATIVE_PATH, appendBlock, logPath, type BlockLogEntry } from "../log.ts";

const dirs: string[] = [];

function tempDir(): string {
	const dir = mkdtempSync(path.join(tmpdir(), "block-sensitive-log-"));
	dirs.push(dir);
	return dir;
}

function readEntries(cwd: string): BlockLogEntry[] {
	return readFileSync(logPath(cwd), "utf8")
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line) as BlockLogEntry);
}

afterEach(() => {
	for (const dir of dirs.splice(0)) {
		rmSync(dir, { recursive: true, force: true });
	}
});

const draft = {
	tool: "read",
	layer: "file-tool" as const,
	rule: ".env",
	matched: "/repo/.env",
	cwd: "/repo",
	sessionId: "session-1",
	input: { path: "/repo/.env" },
};

describe("logPath", () => {
	it("lives under .pi/logs in the session cwd", () => {
		expect(LOG_RELATIVE_PATH).toBe(path.join(".pi", "logs", "blocked-tools.jsonl"));
		expect(logPath("/repo")).toBe("/repo/.pi/logs/blocked-tools.jsonl");
	});
});

describe("appendBlock", () => {
	it("creates the log directory and writes one JSON line", () => {
		const cwd = tempDir();
		expect(appendBlock(draft, cwd)).toBe(logPath(cwd));

		const entries = readEntries(cwd);
		expect(entries).toHaveLength(1);
		expect(entries[0]).toMatchObject({
			tool: "read",
			layer: "file-tool",
			rule: ".env",
			matched: "/repo/.env",
			cwd: "/repo",
			sessionId: "session-1",
		});
		expect(entries[0]!.input).toBe('{"path":"/repo/.env"}');
		expect(new Date(entries[0]!.ts).toISOString()).toBe(entries[0]!.ts);
	});

	it("appends rather than overwriting", () => {
		const cwd = tempDir();
		appendBlock(draft, cwd);
		appendBlock({ ...draft, rule: ".key", matched: "/repo/server.key" }, cwd);

		const entries = readEntries(cwd);
		expect(entries.map((entry) => entry.rule)).toEqual([".env", ".key"]);
	});

	it("records bash commands as their plain string input", () => {
		const cwd = tempDir();
		appendBlock({ ...draft, tool: "bash", layer: "bash", matched: "cat .env", input: "cat .env" }, cwd);
		expect(readEntries(cwd)[0]!.input).toBe("cat .env");
	});

	it("caps very long inputs", () => {
		const cwd = tempDir();
		appendBlock({ ...draft, input: "x".repeat(5000) }, cwd);

		const input = readEntries(cwd)[0]!.input!;
		expect(input).toHaveLength(2003);
		expect(input.endsWith("...")).toBe(true);
	});

	it("omits the input when it cannot be serialized", () => {
		const cwd = tempDir();
		const circular: Record<string, unknown> = {};
		circular.self = circular;

		expect(appendBlock({ ...draft, input: circular }, cwd)).toBe(logPath(cwd));
		expect(readEntries(cwd)[0]!.input).toBeUndefined();
	});

	it("never throws when the log cannot be written", () => {
		const cwd = tempDir();
		// `.pi` exists as a file, so creating `.pi/logs` must fail.
		writeFileSync(path.join(cwd, ".pi"), "not a directory");

		expect(() => appendBlock(draft, cwd)).not.toThrow();
		expect(appendBlock(draft, cwd)).toBeUndefined();
	});
});
