local Config = {}

---@class FileCommands
---@field add_files string|nil Template for adding files. Use %s as placeholder for file paths.
---@field add_files_readonly string|nil Template for adding files as read-only. Use %s as placeholder for file paths.
---@field submit boolean|nil Whether to submit after sending file command (default: false)

---@class TerminalConfig
---@field cmd string | fun(): string
---@field path_header_template string|nil Template for path header in visual selection. Use %s as placeholder for path.
---@field file_commands FileCommands|nil Commands for file operations

---@alias TerminalsMap table<string, TerminalConfig>

---@class WindowDimension
---@field width number
---@field height number

---@alias WindowDimensionsMap table<string, WindowDimension>

---@class TmuxConfig
---@field width? number | (fun(columns: number): number?) Width of the tmux popup (0.0-1.0 as percentage)
---@field height? number | (fun(lines: number): number?) Height of the tmux popup (0.0-1.0 as percentage)
---@field flags? table Tmux popup flags configuration
---@field toggle? table Tmux toggle keymap configuration
---@field on_init? string[] Tmux commands to run after popup creation

---@class AutoTerminalKeymapEntry
---@field name string Terminal name (must match key in terminals config)
---@field key string Single character key suffix for keymaps
---@field enabled? boolean Whether to generate keymaps for this terminal (default: true)

---@class AutoTerminalKeymapsConfig
---@field prefix? string Base prefix for all keymaps (default: "<leader>at")
---@field terminals? AutoTerminalKeymapEntry[] List of terminals to generate keymaps for

---@class ConfigType
---@field terminals TerminalsMap|nil
---@field window_dimensions WindowDimensionsMap|nil
---@field default_position string|nil
---@field enable_diffing boolean|nil
---@field env table|nil
---@field diff_close_keymap string|nil Default: "q"
---@field prompts table<string, string | fun(): string>|nil A table of reusable prompt texts, keyed by a name. Values can be strings or functions returning strings (evaluated at runtime).
---@field prompt_keymaps {key: string, term: string, prompt: string, desc: string, include_selection?: boolean, submit?: boolean}[]|nil Keymaps for prompts (array of tables). `include_selection` (optional, boolean, default: true): If true, the keymap works in normal & visual modes (prefixing selection in visual). If false, it only works in normal mode (no selection). `submit` (optional, boolean, default: true): If true, sends a newline after the prompt.
---@field terminal_keymaps {key: string, action: string | fun(), desc: string, modes?: string | string[]}[]|nil Keymaps that only apply within terminal buffers (array of tables). `modes` (optional, string or array of strings, default: "t"): Specifies the modes for the keymap.
---@field backend "snacks"|"tmux"|nil Terminal backend to use. "snacks" uses snacks.nvim terminal (default), "tmux" uses tmux-toggle-popup.nvim
---@field tmux TmuxConfig|nil Configuration for tmux backend when backend="tmux"
---@field auto_terminal_keymaps AutoTerminalKeymapsConfig|nil Auto-generated keymaps for all configured terminals

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
			path_header_template = "@%s",
		},
		claude = {
			cmd = function()
				return string.format("claude config set -g theme %s && claude", vim.o.background)
			end,
			path_header_template = "@%s",
		},
		aider = {
			cmd = function()
				return string.format("aider --watch-files --%s-mode", vim.o.background)
			end,
			path_header_template = "`%s`",
			file_commands = {
				add_files = "/add %s",
				add_files_readonly = "/read-only %s",
				submit = true,
			},
		},
		codex = {
			cmd = "codex",
			path_header_template = "@%s",
		},
		cursor = {
			cmd = "cursor-agent",
			path_header_template = "@%s",
		},
		gemini = {
			cmd = "gemini -p",
			path_header_template = "@%s",
		},
	},
	window_dimensions = {
		float = { width = 0.9, height = 0.9 },
		bottom = { width = 0.5, height = 0.5 },
		top = { width = 0.5, height = 0.5 },
		left = { width = 0.5, height = 0.5 },
		right = { width = 0.5, height = 0.5 },
	},
	default_position = "right", -- Default position if none is specified in toggle/open/get
	enable_diffing = false, -- Enable backup sync and diff commands. Disabling this prevents `diff_changes` and `close_diff` from working.
	backend = vim.env.TMUX and "tmux" or "snacks", -- Auto-detect: use tmux backend if in tmux session, otherwise snacks
	tmux = {
		-- Tmux popup configuration - simple width/height parameters
		width = 0.9, -- 90% of terminal width (0.0-1.0)
		height = 0.85, -- 85% of terminal height (accounts for tmux status bar)
		flags = {
			close_on_exit = true, -- Close popup when command exits
			start_directory = function()
				-- Try to find git root directory first, fallback to current working directory
				local git_root_cmd = "git rev-parse --show-toplevel 2>/dev/null"
				local git_root = vim.fn.system(git_root_cmd):gsub("\n", "")
				if vim.v.shell_error == 0 and git_root ~= "" then
					return git_root
				else
					return vim.fn.getcwd()
				end
			end, -- Start in git repo root or current working directory
		},
		-- Disable status bar for clean popup appearance
		on_init = {
			"set status off",
		},
		toggle = {
			-- this will be a tmux keybinding so it should be in the format that is acceptable to tmux
			key = "-n C-h",
			mode = "force-close",
		},
	},

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
		-- 	term = "codex",
		-- 	prompt = "summarize_file",
		-- 	desc = "Codex: Summarize current file",
		-- 	include_selection = false,
		-- },
	},
}

return Config
