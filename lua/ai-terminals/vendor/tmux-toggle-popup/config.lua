local M = {}

---@class tmux-toggle-popup.Config: tmux-toggle-popup.Session
---@field log_level? number

---@class tmux-toggle-popup.ConfigUiSize
---@field width? number | (fun(columns: number): number?)
---@field height? number | (fun(lines: number): number?)

---@type tmux-toggle-popup.Config
local defaults = {
	log_level = vim.log.levels.INFO,
	name = "scratch",
	socket_name = "default",
	flags = {
		close_on_exit = true,
		start_directory = function()
			local cwd = vim.uv.cwd()

			return cwd
		end,
		title = function(session)
			return session.name
		end,
	},
	id_format = "#{session_name}/nvim/#{pane_current_path}/{popup_name}",
	command = {},
	env = {},
	width = function(columns)
		if columns < 180 then
			return columns * 0.975
		end

		return columns * 0.9
	end,
	height = function(lines)
		if lines < 60 then
			return lines * 0.95
		end

		return lines * 0.9
	end,
	on_init = {
		"set exit-empty on",
	},
	before_open = {},
	after_close = {},
	kill = true,
	toggle = {
		action = function(_, name)
			return "detach -s " .. name
		end,
	},
}

---@type tmux-toggle-popup.Config
---@diagnostic disable-next-line: missing-fields
M.options = nil

---@return tmux-toggle-popup.Config
function M.read()
	return vim.deepcopy(M.options) or error("Plugin is not configured, call setup() first.")
end

---@param config tmux-toggle-popup.Config
---@return tmux-toggle-popup.Config
function M.setup(config)
	M.options = vim.tbl_deep_extend("force", {}, defaults, config or {})

	vim.validate({
		log_level = { M.options.log_level, "number", true },
	})

	require("ai-terminals.vendor.tmux-toggle-popup.api").validate_session_identifier(M.options)
	require("ai-terminals.vendor.tmux-toggle-popup.api").validate_session_options(M.options)
	require("ai-terminals.vendor.tmux-toggle-popup.api").validate_session_flags(M.options.flags)

	local log = require("ai-terminals.vendor.tmux-toggle-popup.log").setup({ level = M.options.log_level })

	if not require("ai-terminals.vendor.tmux-toggle-popup.utils").is_tmux() then
		log.debug("Not running inside tmux, aborting setup.")

		return M.options
	end

	return M.options
end

return M
