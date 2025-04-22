local Config = {}

---@class TerminalConfig
---@field cmd string | fun(): string

---@alias TerminalsMap table<string, TerminalConfig>

---@class WindowDimension
---@field width number
---@field height number

---@alias WindowDimensionsMap table<string, WindowDimension>

---@class ConfigType
---@field terminals TerminalsMap
---@field window_dimensions WindowDimensionsMap
---@field default_position string
---@field enable_diffing boolean
---@field show_diffs_on_leave boolean

---@type ConfigType
Config.config = {
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
		kode = {
			cmd = function()
				return string.format("kode config set -g theme %s && kode", vim.o.background)
			end,
		},
		aider = {
			cmd = function()
				return string.format("aider --watch-files --%s-mode", vim.o.background)
			end,
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
	-- auto show diffs (if present) when leaving terminal (set to false or nil to disable)
	show_diffs_on_leave = true,
}

return Config
