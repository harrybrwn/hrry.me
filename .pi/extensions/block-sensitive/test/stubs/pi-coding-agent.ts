/**
 * Minimal runtime stand-in for `@earendil-works/pi-coding-agent`.
 *
 * Pi provides the real module at runtime; tests only need the tool-call
 * discriminator, which is a plain name check.
 */

export function isToolCallEventType(name: string, event: { toolName: string }): boolean {
	return event.toolName === name;
}
