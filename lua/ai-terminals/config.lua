local Config = {}

------------------------------------------
-- Configuration
------------------------------------------
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
					"AICHAT_LIGHT_THEME=%s GEMINI_API_BASE=http://localhost:8080/v1beta aichat -r %%functions%% --session",
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
}

------------------------------------------
-- Constants
------------------------------------------
Config.WINDOW_DIMENSIONS = {
	float = { width = 0.97, height = 0.97 },
	bottom = { width = 0.5, height = 0.5 },
	top = { width = 0.5, height = 0.5 },
	left = { width = 0.5, height = 0.5 },
	right = { width = 0.5, height = 0.5 },
}

return Config
