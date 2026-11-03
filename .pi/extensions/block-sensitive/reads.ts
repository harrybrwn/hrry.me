/**
 * File tools layer of `block-sensitive`.
 *
 * Checked per tool:
 *
 *   - read   -> `path`
 *   - grep   -> `path` (searching inside the file) or `glob` (which files to search)
 *   - find   -> `path` / `pattern` naming protected files
 *   - ls     -> `path` (name-only, blocked for consistency)
 *
 * `write` / `edit` are not covered here — only reads are blocked.
 */

import { isToolCallEventType, type ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { matchGlob, matchPath, type Hit, type Rule } from "./shared.ts";

export function inspectToolCall(event: ToolCallEvent, cwd: string): Hit | undefined {
	let rule: Rule | undefined;
	let matched: string | undefined;

	const checkPath = (target: string | undefined) => {
		const found = matchPath(target, cwd);
		if (found) {
			rule = found;
			matched = target;
		}
		return Boolean(found);
	};

	const checkGlob = (pattern: string | undefined, label: string) => {
		const found = matchGlob(pattern);
		if (found) {
			rule = found;
			matched = `${label} ${pattern}`;
		}
		return Boolean(found);
	};

	if (isToolCallEventType("read", event)) {
		checkPath(event.input.path);
	} else if (isToolCallEventType("grep", event)) {
		if (!checkPath(event.input.path)) checkGlob(event.input.glob, "glob");
	} else if (isToolCallEventType("find", event)) {
		if (!checkPath(event.input.path)) checkGlob(event.input.pattern, "pattern");
	} else if (isToolCallEventType("ls", event)) {
		checkPath(event.input.path);
	}

	return rule && matched ? { rule, matched } : undefined;
}
