local M = {}

---Get the current visual selection
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[] lines Selected lines
---@return string filepath Filepath of the buffer
---@return number start_line Starting line number
---@return number end_line Ending line number
function M.get_visual_selection(bufnr)
	local api = vim.api
	local esc_feedkey = api.nvim_replace_termcodes("<ESC>", true, false, true)
	bufnr = bufnr or 0

	api.nvim_feedkeys(esc_feedkey, "n", true)
	api.nvim_feedkeys("gv", "x", false)
	api.nvim_feedkeys(esc_feedkey, "n", true)

	local end_line, end_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))
	local start_line, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
	local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	-- get whole buffer if there is no current/previous visual selection
	if start_line == 0 then
		lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
		start_line = 1
		start_col = 0
		end_line = #lines
		end_col = #lines[#lines]
	end

	-- use 1-based indexing and handle selections made in visual line mode
	start_col = start_col + 1
	end_col = math.min(end_col, #lines[#lines] - 1) + 1

	-- shorten first/last line according to start_col/end_col
	lines[#lines] = lines[#lines]:sub(1, end_col)
	lines[1] = lines[1]:sub(start_col)

	local filepath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")

	return lines, filepath, start_line, end_line
end

---Format visual selection with markdown code block and file path
---@param bufnr integer|nil
---@param opts table|nil Options for formatting (preserve_whitespace, etc.)
---@return string|nil
function M.get_visual_selection_with_header(bufnr, opts)
	opts = opts or {}
	bufnr = bufnr or 0
	local lines, path = M.get_visual_selection(bufnr)

	if not lines or #lines == 0 then
		vim.notify("No text selected", vim.log.levels.WARN)
		return nil
	end

	local slines = table.concat(lines, "\n")

	local filetype = vim.bo[bufnr].filetype or ""
	slines = "```" .. filetype .. "\n" .. slines .. "\n```\n"
	return string.format("\n# Path: %s\n%s\n", path, slines)
end

return M
