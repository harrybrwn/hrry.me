import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
	resolve: {
		alias: {
			// Pi injects its own copy of this module at runtime. Tests swap in a tiny
			// stub so they do not have to boot the agent/TUI stack.
			"@earendil-works/pi-coding-agent": fileURLToPath(
				new URL("./test/stubs/pi-coding-agent.ts", import.meta.url),
			),
		},
	},
	test: {
		environment: "node",
		include: ["test/**/*.test.ts"],
	},
});
