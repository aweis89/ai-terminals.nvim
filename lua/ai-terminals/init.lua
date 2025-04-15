local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")
local ConfigLib = require("ai-terminals.config")
local SelectionLib = require("ai-terminals.selection")

local function reload_changes()
	vim.schedule(function() -- Defer execution slightly
		vim.notify("Checking files for changes...", vim.log.levels.INFO)
		for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
			local bnr = bufinfo.bufnr
			-- Check if buffer is valid, loaded, modifiable, and not the terminal buffer itself
			if vim.api.nvim_buf_is_valid(bnr) and bufinfo.loaded and vim.bo[bnr].modifiable then
				-- Use pcall to handle potential errors during checktime
				---@diagnostic disable-next-line
				pcall(vim.cmd, bnr .. "checktime")
			end
		end
	end)
end

---Setup function to merge user configuration with defaults.
---@param user_config table User-provided configuration table.
function M.setup(user_config)
	ConfigLib.config = vim.tbl_deep_extend("force", ConfigLib.config, user_config or {})
	local group_name = "AiTermReload"
	local augroup = vim.api.nvim_create_augroup(group_name, { clear = true })

	local pattern = "term://*ai-terminals.nvim*"

	-- Autocommand to reload buffers when focus leaves the terminal buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		pattern = pattern,
		desc = "Reload buffers when AI terminal loses focus",
		callback = reload_changes,
	})

	-- Autocommand to run backup when entering the terminal window
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = augroup,
		pattern = pattern,
		desc = "Run backup sync when entering AI terminal window",
		callback = DiffLib.pre_sync_code_base,
	})
end

---Create or toggle a terminal by name with specified position
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil
	end

	position = position or ConfigLib.config.default_position
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }
	if not valid_positions[position] then
		vim.notify(
			"Invalid terminal position: " .. tostring(position) .. ". Falling back to default: " .. ConfigLib.config.default_position,
			vim.log.levels.WARN
		)
		position = ConfigLib.config.default_position -- Fallback to configured default on invalid input
	end

	local selection = nil
	if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		selection = M.get_visual_selection_with_header(0)
	end

	local dimensions = ConfigLib.config.window_dimensions[position]
	local term = TerminalLib.toggle(term_config.cmd, position, dimensions)
	-- Check if in visual mode before sending selection
	if selection then
		M.send(selection, { term = term })
	end
	return term
end

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.get(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, false
	end

	position = position or ConfigLib.config.default_position -- Use configured default if not provided
	local dimensions = ConfigLib.config.window_dimensions[position]
	return TerminalLib.get(term_config.cmd, position, dimensions)
end

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.open(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, false
	end

	position = position or ConfigLib.config.default_position -- Use configured default if not provided
	local dimensions = ConfigLib.config.window_dimensions[position]
	return TerminalLib.open(term_config.cmd, position, dimensions)
end

---Compare current directory with its backup and open differing files (delegates to DiffLib)
---@return nil
function M.diff_changes()
	DiffLib.diff_changes()
end

---Close and wipe out any buffers from the diff directory (delegates to DiffLib)
---@return nil
function M.close_diff()
	DiffLib.close_diff()
end

---Send text to a terminal
---@param text string The text to send
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send(text, opts)
	TerminalLib.send(text, opts)
end

---Send diagnostics to a terminal
---@param name string Terminal name (key in M.config.terminals)
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
function M.send_diagnostics(name, opts)
	local diagnostics = M.diagnostics()
	if not diagnostics then
		vim.notify("No diagnostics found", vim.log.levels.ERROR)
		return
	end
	opts = opts or {}
	if not opts.term then
		opts.term = M.open(name)
	end
	M.send(diagnostics, opts)
end

---Get formatted diagnostics (delegates to DiagnosticsLib)
---@return string|nil
function M.diagnostics()
	return DiagnosticsLib.get_formatted()
end

---Format diagnostics simply (delegates to DiagnosticsLib)
---@param diagnostics table A list of diagnostic items from vim.diagnostic.get()
---@return string[] A list of formatted diagnostic strings
function M.diag_format(diagnostics)
	return DiagnosticsLib.format_simple(diagnostics)
end

---Add a comment above the current line based on user input (delegates to AiderLib)
---@param prefix string The prefix to add before the user's comment text
---@return nil
function M.aider_comment(prefix)
	AiderLib.comment(M, prefix)
end

-- Helper function to send commands to the aider terminal (delegates to AiderLib)
---@param files string[] List of file paths to add to aider
---@param opts? { read_only?: boolean } Options for the command
function M.aider_add_files(files, opts)
	AiderLib.add_files(M, files, opts)
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param term_name string
---@param cmd string|nil The shell command to execute.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send_command_output(term_name, cmd, opts)
	local term = M.open(term_name)
	opts = opts or {}
	opts.term = opts.term or term
	TerminalLib.run_command_and_send_output(cmd, opts)
end

---Get the current visual selection (delegates to SelectionLib)
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[]|nil lines Selected lines (nil if no selection)
---@return string|nil filepath Filepath of the buffer (nil if no selection)
---@return number start_line Starting line number (0 if no selection)
---@return number end_line Ending line number (0 if no selection)
function M.get_visual_selection(bufnr)
	return SelectionLib.get_visual_selection(bufnr)
end

---Format visual selection with markdown code block and file path (delegates to SelectionLib)
---@param bufnr integer|nil
---@return string|nil
function M.get_visual_selection_with_header(bufnr)
	return SelectionLib.get_visual_selection_with_header(bufnr)
end

return M
