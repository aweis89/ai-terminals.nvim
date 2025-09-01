local Diagnostics = {}

-- Helper function to map severity enum to string
local function get_severity_str(severity)
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}
	return severity_map[severity] or "UNKNOWN"
end

---@return string|nil
-- Enhance diagnostics output for better LLM clarity.
-- Shows full visual selection context if run in visual mode, otherwise shows fixed context.
function Diagnostics.get_formatted()
	local diagnostics = {}
	local bufnr = vim.api.nvim_get_current_buf() -- Use current buffer explicitly
	local file = vim.api.nvim_buf_get_name(bufnr)
	local filetype = vim.bo[bufnr].filetype or "" -- Get filetype for code blocks

	local mode = vim.api.nvim_get_mode().mode
	local is_visual_selection = false
	local selection_start_line = 1 -- 1-based
	local selection_end_line = vim.api.nvim_buf_line_count(bufnr) -- 1-based, inclusive

	if mode:match("^[vV\22]") then -- visual, visual-line, or visual-block mode
		local start_mark = vim.api.nvim_buf_get_mark(bufnr, "<")
		local end_mark = vim.api.nvim_buf_get_mark(bufnr, ">")
		-- Ensure marks are valid and start <= end
		if start_mark and end_mark and start_mark[1] > 0 and end_mark[1] > 0 then
			selection_start_line = math.min(start_mark[1], end_mark[1])
			selection_end_line = math.max(start_mark[1], end_mark[1])
			is_visual_selection = true
			-- vim.diagnostic.get uses 0-based line numbers, marks are 1-based
			-- Filter diagnostics to only include those within the visual selection
			local all_diags = vim.diagnostic.get(bufnr)
			for _, diag in ipairs(all_diags) do
				if diag.lnum >= selection_start_line - 1 and diag.lnum <= selection_end_line - 1 then
					table.insert(diagnostics, diag)
				end
			end
		else
			-- Fallback if visual selection is invalid (e.g., just entered visual mode)
			diagnostics = vim.diagnostic.get(bufnr)
		end
	else
		diagnostics = vim.diagnostic.get(bufnr)
	end

	local formatted_output = {}
	local header_message

	if is_visual_selection then
		header_message = string.format(
			"Diagnostics for selection (Lines %d-%d) in file: %q\n",
			selection_start_line,
			selection_end_line,
			file
		)
	else
		header_message = string.format("Diagnostics for file: %q\n", file)
	end

	if #diagnostics == 0 then
		return nil
	end

	-- Sort diagnostics by line number, then column
	table.sort(diagnostics, function(a, b)
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		return a.col < b.col
	end)

	local context_before = 3 -- Fixed context lines (if not visual selection)
	local context_after = 3 -- Fixed context lines (if not visual selection)

	for i, diag in ipairs(diagnostics) do
		table.insert(formatted_output, string.format("--- DIAGNOSTIC %d ---", i))

		-- Neovim diagnostics use 0-based indexing
		local line_nr_1based = diag.lnum + 1
		local col_nr_1based = diag.col + 1
		local severity_str = get_severity_str(diag.severity)
		local message = diag.message:gsub("\n", " ") -- Ensure message is single line
		local source = diag.source or "unknown"

		-- Add diagnostic details
		table.insert(formatted_output, string.format("Severity: %s", severity_str))
		table.insert(formatted_output, string.format("Source:   %s", source))
		table.insert(formatted_output, string.format("Line:     %d", line_nr_1based))
		table.insert(formatted_output, string.format("Column:   %d", col_nr_1based))
		table.insert(formatted_output, string.format("Message:  %s", message))

		-- Fetch context lines based on mode
		local start_context_lnum_0based
		local end_context_lnum_exclusive -- nvim_buf_get_lines end index is exclusive

		if is_visual_selection then
			-- Use the entire visual selection range as context
			start_context_lnum_0based = selection_start_line - 1
			end_context_lnum_exclusive = selection_end_line -- Use the 1-based end line directly
		else
			-- Use fixed context around the diagnostic line
			start_context_lnum_0based = math.max(0, diag.lnum - context_before)
			end_context_lnum_exclusive = math.min(vim.api.nvim_buf_line_count(bufnr), diag.lnum + 1 + context_after)
		end

		-- Check if context range is valid before fetching
		if start_context_lnum_0based >= end_context_lnum_exclusive then
			table.insert(formatted_output, "\nCode Context:\n[Could not fetch context lines for this range]")
		else
			local context_lines =
				vim.api.nvim_buf_get_lines(bufnr, start_context_lnum_0based, end_context_lnum_exclusive, false)

			if context_lines and #context_lines > 0 then
				local context_header = string.format(
					"\nCode Context (Lines %d-%d):",
					start_context_lnum_0based + 1,
					end_context_lnum_exclusive -- Display the correct inclusive end line number
				)
				table.insert(formatted_output, context_header)
				table.insert(formatted_output, "```" .. filetype) -- Start code block

				for line_idx, line_content in ipairs(context_lines) do
					local current_line_nr_0based = start_context_lnum_0based + line_idx - 1
					local current_line_nr_1based = current_line_nr_0based + 1

					local prefix = "  " -- Default prefix
					if current_line_nr_0based == diag.lnum then
						prefix = ">>" -- Highlight diagnostic line
					end
					local line_num_str = string.format("%-4d", current_line_nr_1based) -- Pad line number
					table.insert(formatted_output, string.format("%s %s | %s", prefix, line_num_str, line_content))

					-- Add column marker on the next line if it's the diagnostic line
					if current_line_nr_0based == diag.lnum and col_nr_1based > 0 then
						-- Create a marker string with spaces and then '^'
						local marker_padding = string.rep(" ", col_nr_1based - 1)
						-- Adjust marker position based on prefix and line number width ("prefix Lnum | ")
						-- Length of prefix (2) + space (1) + length of line_num_str + space (1) + pipe (1) + space (1) = #prefix + #line_num_str + 5
						local marker_prefix_padding = string.rep(" ", #prefix + #line_num_str + 5)
						table.insert(formatted_output, marker_prefix_padding .. marker_padding .. "^")
					end
				end
				table.insert(formatted_output, "```") -- End code block
			else
				table.insert(formatted_output, "\nCode Context:\n[Could not fetch context lines]")
			end
		end
		table.insert(formatted_output, "--- END DIAGNOSTIC ---\n") -- Add separator
	end

	return header_message .. "\n" .. table.concat(formatted_output, "\n")
end

---@param diagnostics table A list of diagnostic items from vim.diagnostic.get()
---@return string[] A list of formatted diagnostic strings
function Diagnostics.format_simple(diagnostics)
	local output = {}
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}
	for _, diag in ipairs(diagnostics) do
		local line = string.format(
			"Line %d, Col %d: [%s] %s (%s)",
			diag.lnum + 1, -- Convert from 0-based to 1-based line numbers
			diag.col + 1, -- Convert from 0-based to 1-based column numbers
			severity_map[diag.severity] or "UNKNOWN",
			diag.message,
			diag.source or "unknown"
		)
		table.insert(output, line)
	end
	return output
end

return Diagnostics
