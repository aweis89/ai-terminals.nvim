local Term = require("ai-terminals.terminal")
local Conf = require("ai-terminals.config") -- Need config for some tests

-- Mock necessary vim functions and modules
local mock_notify = {}
local mock_chansend_calls = {}
local mock_feedkeys_calls = {}

-- Keep track of original functions/modules to restore them
local original_vim_notify = vim.notify
local original_vim_fn -- Store original vim.fn table (initialized in before_each)
local original_vim_api = vim.api -- Store original vim.api table
local original_vim_b = vim.b -- Store the original vim.b
local original_vim_fn_feedkeys -- Store original vim.fn.feedkeys

describe("ai-terminals.terminal", function()
	before_each(function()
		-- Reset mocks before each test
		mock_notify = {}
		mock_chansend_calls = {}
		mock_feedkeys_calls = {}

		-- Mock vim.notify
		vim.notify = function(msg, level, opts)
			table.insert(mock_notify, { msg = msg, level = level, opts = opts })
		end

		-- Store original vim.fn if not already stored
		if not original_vim_fn then
			original_vim_fn = vim.fn
		end
		-- Ensure vim.fn and vim.api tables exist before mocking members
		vim.fn = vim.fn or {}
		vim.api = vim.api or {}
		-- Store original feedkeys if not already stored
		if not original_vim_fn_feedkeys then
			original_vim_fn_feedkeys = vim.fn.feedkeys
		end


		-- Mock vim.fn.chansend
		vim.fn.chansend = function(job_id, data)
			table.insert(mock_chansend_calls, { job_id = job_id, data = data })
			return 1 -- Simulate success (chansend returns 1 on success)
		end

		-- Mock vim.fn.feedkeys (used by Term.send)
		vim.fn.feedkeys = function(keys, mode)
			table.insert(mock_feedkeys_calls, { keys = keys, mode = mode })
		end

		-- Mock vim.b with a simple table
		vim.b = {
			terminal_job_id = 123, -- Default mock job ID
		}

		-- Mock minimal config needed for tests
		Conf.config = {
			terminals = {
				test_term_str = { cmd = "echo test" },
				test_term_func = {
					cmd = function()
						return "echo func test"
					end,
				},
				test_term_invalid = { cmd = 12345 }, -- Invalid cmd type
			},
			default_position = "float",
			window_dimensions = {
				float = { height = 20, width = 80 },
			},
			enable_diffing = false, -- Default to false unless testing diff features
		}
	end)

	after_each(function()
		-- Restore original functions/modules after each test
		vim.notify = original_vim_notify
		if original_vim_fn then -- Restore vim.fn only if it was stored
			vim.fn = original_vim_fn
		end
		if original_vim_fn_feedkeys then -- Restore feedkeys specifically
			vim.fn.feedkeys = original_vim_fn_feedkeys
		end
		vim.api = original_vim_api -- Restore original vim.api table
		vim.b = original_vim_b -- Restore original vim.b
		-- Clear potentially modified config
		Conf.config = nil -- Or restore to a known default if necessary
	end)

	describe("Term.resolve_command", function()
		it("should return command string when cmd is a string", function()
			local cmd = Term.resolve_command(Conf.config.terminals.test_term_str.cmd)
			assert.are.equal("echo test", cmd)
		end)

		it("should return command string when cmd is a function", function()
			local cmd = Term.resolve_command(Conf.config.terminals.test_term_func.cmd)
			assert.are.equal("echo func test", cmd)
		end)

		it("should return nil and notify on invalid cmd type", function()
			local cmd = Term.resolve_command(Conf.config.terminals.test_term_invalid.cmd)
			assert.is_nil(cmd)
			assert.are.equal(1, #mock_notify)
			assert.are.equal("Invalid 'cmd' type", mock_notify[1].msg)
			assert.are.equal(vim.log.levels.ERROR, mock_notify[1].level)
		end)
	end)

	describe("Term.send", function()
		it("should send single-line text without bracketed paste", function()
			Term.send("hello")
			assert.are.equal(1, #mock_chansend_calls)
			assert.are.equal(123, mock_chansend_calls[1].job_id)
			assert.are.equal("hello", mock_chansend_calls[1].data)
			assert.are.equal(0, #mock_feedkeys_calls) -- No insert mode by default
		end)

		it("should send multi-line text with bracketed paste", function()
			local text = "line1\nline2"
			local expected_data = "\27[200~" .. text .. "\27[201~"
			Term.send(text)
			assert.are.equal(1, #mock_chansend_calls)
			assert.are.equal(123, mock_chansend_calls[1].job_id)
			assert.are.equal(expected_data, mock_chansend_calls[1].data)
			assert.are.equal(0, #mock_feedkeys_calls)
		end)

		it("should send newline when submit is true", function()
			Term.send("hello", { submit = true })
			assert.are.equal(2, #mock_chansend_calls)
			assert.are.equal("hello", mock_chansend_calls[1].data)
			assert.are.equal("\n", mock_chansend_calls[2].data)
			assert.are.equal(0, #mock_feedkeys_calls)
		end)

		it("should enter insert mode when insert_mode is true", function()
			Term.send("hello", { insert_mode = true })
			assert.are.equal(1, #mock_chansend_calls)
			assert.are.equal("hello", mock_chansend_calls[1].data)
			assert.are.equal(1, #mock_feedkeys_calls)
			assert.are.equal("i", mock_feedkeys_calls[1].keys)
		end)

		it("should use opts.term job_id if provided", function()
			-- Mock a term object with a buffer number
			local mock_term_obj = { buf = 999 }
			-- Mock vim.b for that specific buffer number
			local original_b_999 = vim.b[mock_term_obj.buf] -- Store original if exists
			vim.b[mock_term_obj.buf] = { terminal_job_id = 456 }

			Term.send("hello", { term = mock_term_obj })
			assert.are.equal(1, #mock_chansend_calls)
			assert.are.equal(456, mock_chansend_calls[1].job_id) -- Check if the correct job_id was used
			assert.are.equal("hello", mock_chansend_calls[1].data)

			-- Cleanup mock for specific buffer
			vim.b[mock_term_obj.buf] = original_b_999
		end)

		it("should notify error if no job_id found", function()
			-- Unset the default mock job_id
			vim.b.terminal_job_id = nil
			Term.send("hello")
			assert.are.equal(1, #mock_notify)
			assert.are.equal("No terminal job id found", mock_notify[1].msg)
			assert.are.equal(vim.log.levels.ERROR, mock_notify[1].level)
			assert.are.equal(0, #mock_chansend_calls) -- Should not attempt to send
		end)

		it("should notify error if chansend fails for text", function()
			-- Override mock chansend to simulate failure
			vim.fn.chansend = function(job_id, data)
				if data ~= "\n" then -- Fail only for the main text
					-- Simulate failure by returning 0
					return 0
				end
				-- Simulate success for newline and record call
				table.insert(mock_chansend_calls, { job_id = job_id, data = data })
				return true
			end

			Term.send("hello", { submit = true })
			assert.are.equal(1, #mock_notify)
			-- Check the notification message (adjust if Term.send doesn't include the specific error)
			assert.are.equal("Failed to send text to terminal", mock_notify[1].msg)
			assert.are.equal(vim.log.levels.ERROR, mock_notify[1].level)
			assert.are.equal(0, #mock_chansend_calls) -- Should not have recorded calls if it failed immediately
		end)

		it("should notify error if chansend fails for newline", function()
			-- Override mock chansend to simulate failure only for newline
			vim.fn.chansend = function(job_id, data)
				table.insert(mock_chansend_calls, { job_id = job_id, data = data }) -- Record call attempt
				if data == "\n" then
					-- Simulate failure for newline by returning 0
					return 0
				end
				-- Simulate success for main text
				return 1
			end

			Term.send("hello", { submit = true })
			assert.are.equal(1, #mock_notify)
			-- Check the notification message (adjust if Term.send doesn't include the specific error)
			assert.are.equal("Failed to send newline to terminal", mock_notify[1].msg)
			assert.are.equal(vim.log.levels.ERROR, mock_notify[1].level)
			assert.are.equal(2, #mock_chansend_calls) -- Both calls were attempted by the mock
			assert.are.equal("hello", mock_chansend_calls[1].data)
			assert.are.equal("\n", mock_chansend_calls[2].data)
		end)
	end)

	-- Add more describe blocks for other functions (Term.toggle, Term.get, etc.) here
end)
