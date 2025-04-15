local M = {}

---Get the current visual selection
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[]|nil lines Selected lines (nil if no selection)
---@return string|nil filepath Filepath of the buffer (nil if no selection)
---@return number start_line Starting line number (0 if no selection)
---@return number end_line Ending line number (0 if no selection)
function M.get_visual_selection(bufnr)
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

	-- use 1-based indexing and handle selections made in visual line mode
	start_col = start_col + 1
	end_col = math.min(end_col, #lines[#lines] - 1) + 1

	-- shorten first/last line according to start_col/end_col
	lines[#lines] = lines[#lines]:sub(1, end_col)
	lines[1] = lines[1]:sub(start_col)

	local filepath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")

	return lines, filepath, start_line, end_line
end

---Format visual selection with markdown code block and file path.
---Returns nil if no visual selection is found.
---@param bufnr integer|nil
---@return string|nil
function M.get_visual_selection_with_header(bufnr)
	bufnr = bufnr or 0
	local lines, path = M.get_visual_selection(bufnr)

	-- If get_visual_selection returned nil lines, it means no selection was found.
	if not lines then
		return nil
	end

	local slines = table.concat(lines, "\n")

	local filetype = vim.bo[bufnr].filetype or ""
	slines = "```" .. filetype .. "\n" .. slines .. "\n```\n"
	return string.format("\n# Path: %s\n%s\n", path, slines)
end

return M
