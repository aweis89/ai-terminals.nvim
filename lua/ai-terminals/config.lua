local Config = {}

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
}

return Config
