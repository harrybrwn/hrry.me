/**
 * Blocked-call log for `block-sensitive`.
 *
 * Every call the extension blocks appends one JSON line to
 * `<cwd>/.pi/logs/blocked-tools.jsonl`. Only blocked calls are recorded — tool
 * failures unrelated to this extension are left to Pi's own session log.
 *
 * Design rules:
 *
 *   - Logging must never break the block: every fs error is swallowed and the
 *     caller keeps blocking regardless.
 *   - One line per event, append-only, so `tail -f` / `jq` work while Pi runs.
 *   - Only tool *inputs* are recorded (paths, commands), never file contents.
 */

import { appendFileSync, mkdirSync } from "node:fs";
import path from "node:path";

/** Log location, relative to the session cwd. */
export const LOG_RELATIVE_PATH = path.join(".pi", "logs", "blocked-tools.jsonl");

/** Cap for recorded inputs, so one giant command cannot bloat the log. */
const MAX_INPUT_CHARS = 2000;

export interface BlockLogEntry {
	/** ISO 8601 timestamp, added by `appendBlock`. */
	ts: string;
	/** Tool that was blocked (`bash`, `read`, `grep`, `find`, `ls`). */
	tool: string;
	/** Which layer caught it. */
	layer: "bash" | "file-tool";
	/** Id of the rule that matched (`.env`, `config/k8s/*.json`, ...). */
	rule: string;
	/** What the rule matched (resolved path, glob or command). */
	matched: string;
	/** Session cwd, so relative paths stay interpretable. */
	cwd: string;
	/** Pi session id, when the context exposes one. */
	sessionId?: string;
	/** Raw tool input (paths/commands only, capped). */
	input?: string;
}

/**
 * A draft entry as the extension produces it: `input` is the raw tool input and
 * `ts` is added by `appendBlock`.
 */
export type BlockLogDraft = Omit<BlockLogEntry, "ts" | "input"> & { input?: unknown };

/** Absolute path of the log file for a session cwd. */
export function logPath(cwd: string): string {
	return path.join(cwd, LOG_RELATIVE_PATH);
}

function serialize(value: unknown): string | undefined {
	if (value === undefined) return undefined;

	let text: string;
	try {
		text = typeof value === "string" ? value : JSON.stringify(value);
	} catch {
		return undefined;
	}

	if (text === undefined) return undefined;
	return text.length > MAX_INPUT_CHARS ? `${text.slice(0, MAX_INPUT_CHARS)}...` : text;
}

/**
 * Append one blocked call to the log.
 *
 * @returns the log file path, or `undefined` when the entry could not be written.
 */
export function appendBlock(draft: BlockLogDraft, cwd: string): string | undefined {
	const file = logPath(cwd);

	const entry: BlockLogEntry = {
		ts: new Date().toISOString(),
		...draft,
		input: serialize(draft.input),
	};

	try {
		mkdirSync(path.dirname(file), { recursive: true });
		appendFileSync(file, `${JSON.stringify(entry)}\n`, "utf8");
		return file;
	} catch {
		return undefined;
	}
}
