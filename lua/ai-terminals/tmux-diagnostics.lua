local M = {}

---Check if tmux popup-toggle plugin is properly installed
---@return boolean, string
function M.check_tmux_popup_plugin()
	-- Check if we're in tmux
	if not vim.env.TMUX then
		return false, "Not running in tmux session"
	end

	-- Check if the popup-toggle variable is defined
	local cmd = "tmux show -gv @popup-toggle 2>/dev/null"
	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	if exit_code ~= 0 then
		return false,
			"tmux @popup-toggle variable not defined. Make sure you have installed the tmux popup-toggle plugin and added it to your tmux.conf"
	end

	if result == "" or vim.trim(result) == "" then
		return false, "tmux @popup-toggle variable is empty"
	end

	return true, "tmux popup-toggle plugin is properly configured: " .. vim.trim(result)
end

---Check all tmux requirements
---@return table Diagnostic results
function M.diagnose()
	local results = {}

	-- Check tmux session
	table.insert(results, {
		name = "tmux session",
		status = vim.env.TMUX and "✓" or "✗",
		message = vim.env.TMUX and "Running in tmux session" or "Not in tmux session",
	})

	-- Check popup toggle plugin
	local popup_ok, popup_msg = M.check_tmux_popup_plugin()
	table.insert(results, {
		name = "popup-toggle plugin",
		status = popup_ok and "✓" or "✗",
		message = popup_msg,
	})

	-- Check tmux version
	local tmux_version = vim.fn.system("tmux -V 2>/dev/null")
	local version_ok = vim.v.shell_error == 0
	table.insert(results, {
		name = "tmux version",
		status = version_ok and "✓" or "✗",
		message = version_ok and vim.trim(tmux_version) or "tmux not found in PATH",
	})

	return results
end

---Print diagnostic results
function M.print_diagnostics()
	local results = M.diagnose()
	print("=== AI Terminals Tmux Backend Diagnostics ===")
	for _, result in ipairs(results) do
		print(string.format("%s %s: %s", result.status, result.name, result.message))
	end
	print("===============================================")
end

---Debug environment variable passing
function M.debug_env_vars()
	print("=== Environment Variables Debug ===")

	-- Show current shell
	local shell = vim.env.SHELL or "unknown"
	print(string.format("Current shell: %s", shell))

	-- Show config env overrides only
	local config = require("ai-terminals.config").config
	print("\nConfig env overrides (only these will be explicitly passed to tmux):")
	if config.env and next(config.env) then
		for k, v in pairs(config.env) do
			print(string.format("config.env.%s = %s", k, tostring(v)))
		end
	else
		print("(no config env overrides - tmux will use shell's natural environment)")
	end

	print("\nNote: All other environment variables will be inherited through")
	print("the shell's initialization files (.zshrc, .bashrc, etc.)")
	print("====================================")
end

return M
