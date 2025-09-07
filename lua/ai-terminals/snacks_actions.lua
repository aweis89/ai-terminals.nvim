---@class AITerminals.SnacksActions
---Optional Snacks integration: actions + default keymaps
---
---Usage (with lazy.nvim):
---  opts = function(_, opts)
---    local sa = require("ai-terminals.snacks_actions")
---    opts = sa.apply(opts) -- merges actions and default keymaps without overriding user config
---    return opts
---  end
local M = {}
local Config = require("ai-terminals.config")

-- Internal logging helper (quiet by default)
local function log(msg, level)
	if vim.g.ai_terminals_snacks_actions_notify == false then
		return
	end
	vim.notify(msg, level or vim.log.levels.DEBUG, { title = "ai-terminals.snacks" })
end

-- Detect directory via libuv
local function is_dir(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	local s = (vim.uv or vim.loop).fs_stat(path)
	return s and s.type == "directory" or false
end

-- Extract absolute path for a Snacks picker item.
-- Prefers Snacks.picker.util.path(item), falls back to common fields.
local function item_abs_path(item)
	local ok, Snacks = pcall(require, "snacks")
	if ok and Snacks and Snacks.picker and Snacks.picker.util and Snacks.picker.util.path then
		local ok2, p = pcall(Snacks.picker.util.path, item)
		if ok2 and type(p) == "string" and p ~= "" then
			return p
		end
	end
	-- Fallbacks
	local cand = item and (item.path or item.file or item.value)
	if type(cand) == "string" and cand ~= "" then
		return vim.fn.fnamemodify(cand, ":p")
	end
	return nil
end

-- Core helper used by actions to add files from a picker into a terminal
local function add_files_from_picker(picker, term, opts)
	if not picker or type(picker.selected) ~= "function" then
		log("invalid picker; cannot read selection", vim.log.levels.WARN)
		return
	end

	local selected = picker:selected({ fallback = true }) or {}
	local files_to_add = {}

	for _, item in pairs(selected) do
		if item and (item.file or item.path or item.value) then
			local abs_path = item_abs_path(item)
			if abs_path then
				table.insert(files_to_add, abs_path)
			end
		else
			local text = (item and item.text) and tostring(item.text) or "<no text>"
			vim.notify(
				"No file associated with selected item: " .. text,
				vim.log.levels.WARN,
				{ title = "ai-terminals" }
			)
		end
	end

	-- Special-case: Claude supports /add-dir when a single directory is selected
	if term == "claude" and #files_to_add == 1 and is_dir(files_to_add[1]) then
		local ok, ai = pcall(require, "ai-terminals")
		if not ok then
			return
		end
		ai.send_term(term, "/add-dir " .. files_to_add[1], { focus = true, submit = true })
		return
	end

	if #files_to_add == 0 then
		log("no files to add", vim.log.levels.DEBUG)
		return
	end

	local ok, ai = pcall(require, "ai-terminals")
	if not ok then
		log("ai-terminals not available", vim.log.levels.WARN)
		return
	end
	ai.add_files_to_terminal(term, files_to_add, opts)
end

-- Build actions dynamically for all configured terminals
local function build_actions()
	local actions = {}

	local function add_action(name, fn)
		if not actions[name] then
			actions[name] = fn
		end
	end

	local terminals = (Config and Config.config and Config.config.terminals) or {}
	if type(terminals) == "table" and next(terminals) ~= nil then
		for term, tcfg in pairs(terminals) do
			-- <term>_add
			add_action(term .. "_add", function(picker)
				if picker and picker.close then
					picker:close()
				end
				add_files_from_picker(picker, term)
			end)

			-- <term>_read_only when supported (presence of add_files_readonly)
			local fc = tcfg and tcfg.file_commands or nil
			if fc and fc.add_files_readonly then
				add_action(term .. "_read_only", function(picker)
					if picker and picker.close then
						picker:close()
					end
					add_files_from_picker(picker, term, { read_only = true })
				end)
			end
		end
	else
		-- Fallback defaults if no terminals are configured yet
		add_action("aider_add", function(picker)
			if picker and picker.close then
				picker:close()
			end
			add_files_from_picker(picker, "aider")
		end)
		add_action("aider_read_only", function(picker)
			if picker and picker.close then
				picker:close()
			end
			add_files_from_picker(picker, "aider", { read_only = true })
		end)
		add_action("claude_add", function(picker)
			if picker and picker.close then
				picker:close()
			end
			add_files_from_picker(picker, "claude")
		end)
		add_action("codex_add", function(picker)
			if picker and picker.close then
				picker:close()
			end
			add_files_from_picker(picker, "codex")
		end)
	end

	return actions
end

-- Public actions exposed to Snacks pickers
M.actions = build_actions()

-- Default pickers to which we add keymaps
local file_action_pickers = {
	"buffers",
	"files",
	"git_diff",
	"git_files",
	"git_log_file",
	"git_log",
	"git_status",
	"grep_buffers",
	"grep_word",
	"grep",
	"projects",
	"recent",
	"smart",
	"explorer",
}

-- Default key mappings for those pickers
local function build_default_keys(actions)
	-- If user configured auto_terminal_keymaps, derive keys from it so all
	-- terminals are covered and keys stay consistent with the rest of the plugin.
	local auto = (Config and Config.config and Config.config.auto_terminal_keymaps) or {}
	local keys = {}
	local function add(lhs, rhs)
		if lhs and rhs then
			keys[lhs] = { rhs, mode = { "n", "i" } }
		end
	end

  local has_auto = type(auto) == "table" and type(auto.terminals) == "table" and #auto.terminals > 0
  if not has_auto then
    return keys -- no auto keymaps configured; expose actions only (no defaults)
  end

  for _, entry in ipairs(auto.terminals) do
    if entry and entry.enabled ~= false and type(entry.name) == "string" and type(entry.key) == "string" then
      local add_action = entry.name .. "_add"
      if actions[add_action] then
        add("<localleader>a" .. entry.key, add_action)
      end
      local ro_action = entry.name .. "_read_only"
      if actions[ro_action] then
        add("<localleader>A" .. entry.key, ro_action)
      end
    end
  end
  return keys
end

-- Ensure nested table path exists and return the final table
local function ensure(tbl, keys)
	local t = tbl
	for _, k in ipairs(keys) do
		t[k] = t[k] or {}
		t = t[k]
	end
	return t
end

-- Apply our actions and default keymaps to Snacks opts without overriding user config
-- - Actions are merged with `keep` (user wins on conflicts)
-- - Keymaps are only added when the key is not already defined by the user
function M.apply(opts)
	opts = opts or {}
	opts.picker = opts.picker or {}

	-- Merge actions (do not overwrite user-defined actions)
	opts.picker.actions = vim.tbl_deep_extend("keep", opts.picker.actions or {}, M.actions)

	-- Add default keymaps for a set of pickers; do not overwrite existing keys
	local sources = ensure(opts, { "picker", "sources" })
	local default_keys = build_default_keys(M.actions)
	for _, name in ipairs(file_action_pickers) do
		local keys_tbl = ensure(sources, { name, "win", "input", "keys" })
		for lhs, spec in pairs(default_keys) do
			if keys_tbl[lhs] == nil then
				keys_tbl[lhs] = spec
			end
		end
	end

	return opts
end

return M
