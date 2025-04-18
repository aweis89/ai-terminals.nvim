local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")
local ConfigLib = require("ai-terminals.config")
local SelectionLib = require("ai-terminals.selection")

---Setup function to merge user configuration with defaults.
---@param user_config table User-provided configuration table.
function M.setup(user_config)
	ConfigLib.config = vim.tbl_deep_extend("force", ConfigLib.config, user_config or {})
end

---Create or toggle a terminal by name with specified position (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	local term = TerminalLib.toggle(terminal_name, position)

	-- Send selection if in visual mode (moved from original M.toggle)
	if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		local selection = M.get_visual_selection_with_header(0)
		if selection and term then
			M.send(selection, { term = term })
		end
	end

	return term
end

---Get an existing terminal instance by name (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.get(terminal_name, position)
	return TerminalLib.get(terminal_name, position)
end

function M.focus()
	TerminalLib.focus()
end

---Open a terminal by name, creating if necessary (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?
function M.open(terminal_name, position)
	return TerminalLib.open(terminal_name, position)
end

---Compare current directory with its backup and open differing files (delegates to DiffLib)
---@param diff_func function|nil A function to be called for diffing instead of using neovim's built-in
---@return nil
function M.diff_changes(diff_func)
	DiffLib.diff_changes(diff_func)
end

---Close and wipe out any buffers from the diff directory (delegates to DiffLib)
---@return nil
function M.close_diff()
	DiffLib.close_diff()
end

---Send text to a terminal (delegates to TerminalLib)
---@param text string The text to send
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send(text, opts)
	TerminalLib.send(text, opts)
end

---Send text to a specific named terminal
---@param name string Terminal name (key in M.config.terminals)
---@param text string text to send
---@param opts {submit?: boolean}|nil Options: `submit` sends a newline after the text if true.
function M.send_term(name, text, opts)
	local term = M.open(name) -- Use M.open which delegates to TerminalLib.open
	if not term then
		vim.notify("Terminal '" .. name .. "' not found or could not be opened", vim.log.levels.ERROR)
		return
	end
	opts = opts or {}
	M.send(text, {
		term = term,
		submit = opts.submit or false,
	})
end

---Send diagnostics to a specific named terminal
---@param name string Terminal name (key in M.config.terminals)
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
function M.send_diagnostics(name, opts)
	local diagnostics = M.diagnostics()
	if not diagnostics or #diagnostics == 0 then
		vim.notify("No diagnostics found", vim.log.levels.WARN)
		return
	end
	opts = opts or {}
	local term = opts.term or M.toggle(name)
	if not term then
		vim.notify("Terminal '" .. name .. "' not found or could not be toggled", vim.log.levels.ERROR)
		return
	end
	M.send(diagnostics, { term = term, submit = opts.submit or false })
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
	AiderLib.comment(prefix)
end

-- Helper function to send commands to the aider terminal (delegates to AiderLib)
---@param files string[] List of file paths to add to aider
---@param opts? { read_only?: boolean } Options for the command
function M.aider_add_files(files, opts)
	AiderLib.add_files(files, opts)
end

-- Add all buffers to aider (delegates to AiderLib)
function M.aider_add_buffers()
	AiderLib.add_buffers()
end

---Destroy all active AI terminals (closes windows and stops processes).
---The next toggle/open will create new instances.
function M.destroy_all()
	TerminalLib.destroy_all()
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param term_name string
---@param cmd string|nil The shell command to execute.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send_command_output(term_name, cmd, opts)
	local term = M.open(term_name) -- Use M.open which delegates
	if not term then
		vim.notify(
			"Terminal '" .. term_name .. "' not found or could not be opened for command output",
			vim.log.levels.ERROR
		)
		return
	end
	opts = opts or {}
	opts.term = opts.term or term
	TerminalLib.run_command_and_send_output(cmd, opts) -- Call TerminalLib directly
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
