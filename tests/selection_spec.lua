local Selection = require("ai-terminals.selection")

describe("ai-terminals.selection", function()
	local mock_feedkeys_calls
	local mock_buf_get_mark_calls
	local mock_buf_get_lines_calls
	local mock_fnamemodify_calls
	local mock_expand_calls
	local mock_bo -- Mock for vim.bo

	before_each(function()
		-- Reset mocks before each test
		mock_feedkeys_calls = {}
		mock_buf_get_mark_calls = {}
		mock_buf_get_lines_calls = {}
		mock_fnamemodify_calls = {}
		mock_expand_calls = {}
		mock_bo = { -- Default mock buffer options
			filetype = "lua",
		}

		-- Mock Neovim API functions
		vim = vim or {}
		vim.api = vim.api or {}
		vim.fn = vim.fn or {}
		vim.bo = setmetatable({}, { -- Use metatable to handle different buffer numbers if needed
			__index = function(_, bufnr)
				-- For simplicity, return the same mock_bo for any buffer number accessed
				-- In a more complex scenario, you might store mock options per bufnr
				return mock_bo
			end,
		})

		vim.api.nvim_replace_termcodes = function(str, ...)
			return str -- Simple mock, just return the input string
		end

		vim.api.nvim_feedkeys = function(keys, mode, escape_ks)
			table.insert(mock_feedkeys_calls, { keys = keys, mode = mode, escape_ks = escape_ks })
		end

		vim.api.nvim_buf_get_mark = function(bufnr, name)
			table.insert(mock_buf_get_mark_calls, { bufnr = bufnr, name = name })
			-- Simulate different return values based on the test case needs
			if _TEST_MARK_START_LINE == 0 then -- Simulate no selection
				if name == "<" then
					return { 0, 0 }
				else -- name == ">"
					return { 0, 0 } -- Or whatever is appropriate for no selection end mark
				end
			else
				if name == "<" then
					return { _TEST_MARK_START_LINE or 1, _TEST_MARK_START_COL or 0 }
				else -- name == ">"
					return { _TEST_MARK_END_LINE or 1, _TEST_MARK_END_COL or 5 }
				end
			end
		end

		vim.api.nvim_buf_get_lines = function(bufnr, start, end_, strict_indexing)
			table.insert(mock_buf_get_lines_calls, {
				bufnr = bufnr,
				start = start,
				end_ = end_,
				strict_indexing = strict_indexing,
			})
			-- Return predefined lines for testing
			return _TEST_LINES or { "line1 content", "line2 content" }
		end

		vim.fn.fnamemodify = function(fname, mods)
			table.insert(mock_fnamemodify_calls, { fname = fname, mods = mods })
			return _TEST_FILENAME or "mock/file/path.lua"
		end

		vim.fn.expand = function(expr)
			table.insert(mock_expand_calls, { expr = expr })
			if expr == "%" then
				return _TEST_RAW_FILENAME or "/abs/path/to/mock/file/path.lua"
			end
			return ""
		end

		-- Helper variables to control mock behavior per test
		_TEST_MARK_START_LINE = 1
		_TEST_MARK_START_COL = 0
		_TEST_MARK_END_LINE = 1
		_TEST_MARK_END_COL = 5 -- Example: select 'line1' from "line1 content"
		_TEST_LINES = { "line1 content" }
		_TEST_FILENAME = "mock/file/path.lua"
		_TEST_RAW_FILENAME = "/abs/path/to/mock/file/path.lua"
	end)

	describe("Selection.get_visual_selection", function()
		it("should return nil if no visual selection mark '<' exists", function()
			_TEST_MARK_START_LINE = 0 -- Simulate no '<' mark

			local lines, filepath, start_line, end_line = Selection.get_visual_selection(0)

			assert.is_nil(lines)
			assert.is_nil(filepath)
			assert.are.equal(0, start_line)
			assert.are.equal(0, end_line)
			-- Check feedkeys were called by checking the mock table length
			assert.are.equal(3, #mock_feedkeys_calls)
		end)

		it("should return selection details for a single line selection", function()
			_TEST_MARK_START_LINE = 5
			_TEST_MARK_START_COL = 2 -- Select from 3rd char (index 2)
			_TEST_MARK_END_LINE = 5
			_TEST_MARK_END_COL = 7 -- Select up to 8th char (index 7)
			_TEST_LINES = { "this is line five" }
			_TEST_FILENAME = "test.txt"

			local lines, filepath, start_line, end_line = Selection.get_visual_selection(0)

			-- Corrected expectation based on calculation: start_col=2, end_col=7 (0-based) -> sub(3, 8) (1-based) -> "is is "
			assert.are.same({ "is is " }, lines)
			assert.are.equal("test.txt", filepath)
			assert.are.equal(5, start_line)
			assert.are.equal(5, end_line)
			-- Check mock call table for arguments
			assert.are.same({ bufnr = 0, start = 4, end_ = 5, strict_indexing = false }, mock_buf_get_lines_calls[1])
			assert.are.same({ fname = _TEST_RAW_FILENAME, mods = ":~:." }, mock_fnamemodify_calls[1])
		end)

		it("should return selection details for a multi-line selection", function()
			_TEST_MARK_START_LINE = 2
			_TEST_MARK_START_COL = 3 -- Start from 4th char
			_TEST_MARK_END_LINE = 3
			_TEST_MARK_END_COL = 4 -- End at 5th char
			_TEST_LINES = { "line two starts here", "line three ends here" }
			_TEST_FILENAME = "multi.lua"

			local lines, filepath, start_line, end_line = Selection.get_visual_selection(0)

			assert.are.same({ "e two starts here", "line " }, lines) -- line 2: sub(4), line 3: sub(1, 5)
			assert.are.equal("multi.lua", filepath)
			assert.are.equal(2, start_line)
			assert.are.equal(3, end_line)
			-- Check mock call table for arguments
			assert.are.same({ bufnr = 0, start = 1, end_ = 3, strict_indexing = false }, mock_buf_get_lines_calls[1])
		end)

		it("should handle visual line selection correctly", function()
			-- Visual line mode often selects full lines, start col 0, end col very large
			_TEST_MARK_START_LINE = 2
			_TEST_MARK_START_COL = 0
			_TEST_MARK_END_LINE = 3
			_TEST_MARK_END_COL = 1000 -- Simulate end col beyond line length
			_TEST_LINES = { "full line two", "full line three" }
			_TEST_FILENAME = "visualline.md"

			local lines, filepath, start_line, end_line = Selection.get_visual_selection(0)

			-- Expect full lines because start_col=0 and end_col is clamped
			assert.are.same({ "full line two", "full line three" }, lines)
			assert.are.equal("visualline.md", filepath)
			assert.are.equal(2, start_line)
			assert.are.equal(3, end_line)
		end)
	end)

	describe("Selection.get_visual_selection_with_header", function()
		it("should return nil if get_visual_selection returns nil", function()
			_TEST_MARK_START_LINE = 0 -- Simulate no selection

			local result = Selection.get_visual_selection_with_header(0)
			assert.is_nil(result)
		end)

		it("should return formatted string with header for a valid selection", function()
			_TEST_MARK_START_LINE = 1
			_TEST_MARK_START_COL = 0
			_TEST_MARK_END_LINE = 2
			_TEST_MARK_END_COL = 4 -- Select "line" from second line
			_TEST_LINES = { "first line", "second line" }
			_TEST_FILENAME = "my/code.lua"
			mock_bo.filetype = "lua" -- Set mock filetype

			local result = Selection.get_visual_selection_with_header(0)

			-- Corrected expectation: end_col=4 (0-based) -> end_col=5 (1-based). sub(1, 5) -> "secon"
			local expected_selection = { "first line", "secon" }
			local expected_text = table.concat(expected_selection, "\n")
			-- Corrected expected output format (no double newline at the end)
			local expected_output = string.format("\n# Path: %s\n```%s\n%s\n```\n", _TEST_FILENAME, mock_bo.filetype, expected_text)

			assert.are.equal(expected_output, result)
		end)

		it("should use empty string for filetype if vim.bo[bufnr].filetype is nil", function()
			_TEST_MARK_START_LINE = 1
			_TEST_MARK_START_COL = 0
			_TEST_MARK_END_LINE = 1
			_TEST_MARK_END_COL = 5
			_TEST_LINES = { "some text" }
			_TEST_FILENAME = "file.unknown"
			mock_bo.filetype = nil -- Simulate nil filetype

			local result = Selection.get_visual_selection_with_header(0)

			-- Corrected expectation: end_col=5 (0-based) -> end_col=6 (1-based). sub(1, 6) -> "some t"
			local expected_selection = { "some t" }
			local expected_text = table.concat(expected_selection, "\n")
			-- Corrected expected output format (no double newline at the end)
			local expected_output = string.format(
				"\n# Path: %s\n```%s\n%s\n```\n",
				_TEST_FILENAME,
				"", -- Empty filetype
				expected_text
			)

			assert.are.equal(expected_output, result)
		end)
	end)
end)
