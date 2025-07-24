local Config = {}

---@class TerminalConfig
---@field cmd string | fun(): string

---@alias TerminalsMap table<string, TerminalConfig>

---@class WindowDimension
---@field width number
---@field height number

---@alias WindowDimensionsMap table<string, WindowDimension>

---@class ConfigType
---@field terminals TerminalsMap|nil
---@field window_dimensions WindowDimensionsMap|nil
---@field default_position string|nil
---@field enable_diffing boolean|nil
---@field env table|nil
---@field show_diffs_on_leave boolean|table|nil
---@field diff_close_keymap string|nil Default: "q"
---@field clipboard_register string|false|nil         # Register name to use when sending text to terminal. Set to false to disable. Defaults to "a" when nil.
---@field prompts table<string, string | fun(): string>|nil A table of reusable prompt texts, keyed by a name. Values can be strings or functions returning strings (evaluated at runtime).
---@field prompt_keymaps {key: string, term: string, prompt: string, desc: string, include_selection?: boolean, submit?: boolean}[]|nil Keymaps for prompts (array of tables). `include_selection` (optional, boolean, default: true): If true, the keymap works in normal & visual modes (prefixing selection in visual). If false, it only works in normal mode (no selection). `submit` (optional, boolean, default: true): If true, sends a newline after the prompt.
---@field terminal_keymaps {key: string, action: string | fun(), desc: string, modes?: string | string[]}[]|nil Keymaps that only apply within terminal buffers (array of tables). `modes` (optional, string or array of strings, default: "t"): Specifies the modes for the keymap.

---@type ConfigType
Config.config = {
	terminal_keymaps = {
		-- Example: { key = "<localleader>q", action = "close", desc = "Close terminal" },
		-- Example: { key = "<C-k>", action = function() vim.cmd("wincmd k") end, desc = "Move to window above" },
	},
	-- Keymapping used within diff views (vimdiff or delta terminal) to close the diff.
	diff_close_keymap = "q", -- Default: "q"
	env = {
		PAGER = "cat",
	},
	terminals = {
		goose = {
			cmd = function()
				return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)
			end,
		},
		aichat = {
			cmd = function()
				return string.format(
					"AICHAT_LIGHT_THEME=%s aichat -r %%functions%% --session",
					tostring(vim.o.background == "light") -- Convert boolean to string "true" or "false"
				)
			end,
		},
		claude = {
			cmd = function()
				return string.format("claude config set -g theme %s && claude", vim.o.background)
			end,
		},
		aider = {
			cmd = function()
				return string.format("aider --watch-files --%s-mode", vim.o.background)
			end,
		},
		codex = {
			cmd = "codex",
		},
		gemini = {
			cmd = "gemini",
		},
	},
	window_dimensions = {
		float = { width = 0.9, height = 0.9 },
		bottom = { width = 0.5, height = 0.5 },
		top = { width = 0.5, height = 0.5 },
		left = { width = 0.5, height = 0.5 },
		right = { width = 0.5, height = 0.5 },
	},
	default_position = "float", -- Default position if none is specified in toggle/open/get
	enable_diffing = true, -- Enable backup sync and diff commands. Disabling this prevents `diff_changes` and `close_diff` from working.

		clipboard_register = "a",

	-- auto show diffs (if present) when leaving terminal (set to false or nil to disable)
	show_diffs_on_leave = true,
	-- Define reusable prompts
	prompts = {
		explain_code = "Explain the selected code snippet.",
		refactor_code = "Refactor the selected code snippet for clarity and efficiency.",
		find_bugs = "Analyze the selected code snippet for potential bugs or issues.",
		write_tests = "Write unit tests for the selected code snippet.",
		summarize = "Summarize the provided text or code.",
		-- Example: Function prompt using current file context
		summarize_file = function()
			local file_path = vim.fn.expand("%:p") -- Get full path of current buffer
			if file_path == "" then
				return "Summarize the current buffer content."
			else
				return string.format("Summarize the content of the file: `%s`", file_path)
			end
		end,
	},
	-- Define keymaps that use the prompts
	-- Key: A unique name for the mapping (doesn't affect functionality, just for organization)
	-- Value: { key: string, term: string, prompt: string, desc: string, mode?: "v"|"n" }
	--   key: The keybinding (e.g., "<leader>ae")
	--   term: The target terminal name (from `terminals` table)
	--   prompt: The key of the prompt in the `prompts` table
	--   desc: Description for the keymap
	--   include_selection: Optional, defaults to true. If true, keymap works in normal & visual modes (prefixes selection in visual). If false, keymap only works in normal mode.
	--   submit: Optional, defaults to true. If false, no newline is sent after the prompt.
	prompt_keymaps = {
		-- Default behavior: include_selection=true (implicitly), works in n/v modes, prefixes selection in visual
		-- { key = "<leader>ae", term = "aider", prompt = "explain_code", desc = "Aider: Explain selection" },
		-- Example: Include selection (prefix), don't submit automatically, works in n/v modes
		-- {
		-- 	key = "<leader>ar",
		-- 	term = "aider",
		-- 	prompt = "refactor_code",
		-- 	desc = "Aider: Refactor selection",
		-- 	include_selection = true,
		-- 	submit = false,
		-- },
		-- Example: Explicitly include selection (prefix), works in n/v modes
		-- {
		-- 	key = "<leader>ab",
		-- 	term = "aider",
		-- 	prompt = "find_bugs",
		-- 	desc = "Aider: Find bugs",
		-- 	include_selection = true,
		-- },
		-- Example: Don't include selection, only works in normal mode
		-- {
		-- 	key = "<leader>at",
		-- 	term = "aider",
		-- 	prompt = "write_tests",
		-- 	desc = "Aider: Write tests",
		-- 	include_selection = false,
		-- },
		-- { key = "<leader>ce", term = "claude", prompt = "explain_code", desc = "Claude: Explain selection" }, -- include_selection defaults to true
		-- { key = "<leader>cs", term = "claude", prompt = "summarize", desc = "Claude: Summarize selection" }, -- include_selection defaults to true
		-- Example using the function prompt (normal mode only)
		-- {
		-- 	key = "<leader>asf",
		-- 	term = "aichat",
		-- 	prompt = "summarize_file",
		-- 	desc = "Aichat: Summarize current file",
		-- 	include_selection = false,
		-- },
	},
}

return Config
