/**
 * Block reads of sensitive files.
 *
 * Protected patterns (see `shared.ts`):
 *
 *   - secrets   : names ending in `.env`
 *   - certs     : names ending in `.crt` or `.key`
 *   - terraform : names ending in `.tfvars`, or containing `.tfstate`
 *   - k8s       : `.json` files anywhere under `config/k8s/`
 *   - anything  : names containing "password", and files named exactly `htpasswd`
 *
 * Entry point for the extension. One `tool_call` handler, two layers:
 *
 *   - `bash` -> `inspectCommand` in bash.ts (tree-sitter-bash parse)
 *   - everything else -> `inspectToolCall` in reads.ts (`read`, `grep`, `find`, `ls`)
 *
 * Every blocked call is also appended to `.pi/logs/blocked-tools.jsonl` (see log.ts).
 */

import { isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { inspectCommand } from "./bash.ts";
import { inspectToolCall } from "./reads.ts";
import { appendBlock } from "./log.ts";
import { blockReason, type Hit } from "./shared.ts";

/** Keep block reasons readable when the offending command is a long one-liner. */
function truncate(text: string, limit = 140): string {
	const single = text.replace(/\s+/g, " ").trim();
	return single.length > limit ? `${single.slice(0, limit - 3)}...` : single;
}

function sessionId(ctx: ExtensionContext): string | undefined {
	try {
		return ctx.sessionManager?.getSessionId();
	} catch {
		return undefined;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		let hit: Hit | undefined;

		if (isToolCallEventType("bash", event)) {
			const command = event.input.command;
			if (typeof command !== "string" || !command.trim()) return undefined;

			const found = inspectCommand(command, ctx.cwd);
			if (found) hit = { rule: found.rule, matched: truncate(command) };
		} else {
			hit = inspectToolCall(event, ctx.cwd);
		}

		if (!hit) return undefined;

		// Recorded before the notify so a throwing UI does not lose the entry.
		appendBlock(
			{
				tool: event.toolName,
				layer: event.toolName === "bash" ? "bash" : "file-tool",
				rule: hit.rule.id,
				matched: hit.matched,
				cwd: ctx.cwd,
				sessionId: sessionId(ctx),
				input: event.input,
			},
			ctx.cwd,
		);

		if (ctx.hasUI) {
			ctx.ui.notify(`Blocked ${hit.rule.id} access: ${hit.matched}`, "warning");
		}

		return { block: true, reason: blockReason(hit.rule, hit.matched) };
	});
}
