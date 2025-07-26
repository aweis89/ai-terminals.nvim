local Selection = {}

---Get the current visual selection
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[]|nil lines Selected lines (nil if no selection)
---@return string|nil filepath Filepath of the buffer (nil if no selection)
---@return number start_line Starting line number (0 if no selection)
---@return number end_line Ending line number (0 if no selection)
function Selection.get_visual_selection(bufnr)
	local api = vim.api
	local esc_feedkey = api.nvim_replace_termcodes("<ESC>", true, false, true)
	bufnr = bufnr or 0

	api.nvim_feedkeys(esc_feedkey, "n", true)
	api.nvim_feedkeys("gv", "x", false)
	api.nvim_feedkeys(esc_feedkey, "n", true)

	local end_line, end_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))
	local start_line, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
	-- If start_line is 0, it means there was no visual selection mark '<'.
	-- Return nil to indicate no selection was found.
	if start_line == 0 then
		return nil, nil, 0, 0
	end

	local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	-- use 1-based indexing
	start_col = start_col + 1 -- Convert 0-based start col to 1-based for sub
	end_col = end_col + 1 -- Convert 0-based end col to 1-based for sub

	-- shorten first/last line according to start_col/end_col
	-- Clamp end_col to the actual length of the last line before slicing
	lines[#lines] = lines[#lines]:sub(1, math.min(end_col, #lines[#lines]))
	lines[1] = lines[1]:sub(start_col)

	local filepath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")

	return lines, filepath, start_line, end_line
end

---Format visual selection with markdown code block and file path.
---Returns nil if no visual selection is found.
---@param bufnr integer|nil
---@param terminal_name string|nil Optional terminal name to use for path header template
---@return string|nil
function Selection.get_visual_selection_with_header(bufnr, terminal_name)
	bufnr = bufnr or 0
	local lines, path = Selection.get_visual_selection(bufnr)

	-- If get_visual_selection returned nil lines, it means no selection was found.
	if not lines then
		return nil
	end

	local slines = table.concat(lines, "\n")

	local filetype = vim.bo[bufnr].filetype or ""
	slines = "```" .. filetype .. "\n" .. slines .. "\n```"

	-- Get path header template from terminal config or use default
	local path_header = "# Path: %s"
	if terminal_name then
		local Config = require("ai-terminals.config")
		local terminal_config = Config.config.terminals and Config.config.terminals[terminal_name]
		if terminal_config and terminal_config.path_header_template then
			path_header = terminal_config.path_header_template
		end
	end

	return string.format("\n%s\n%s\n", string.format(path_header, path), slines)
end

return Selection
