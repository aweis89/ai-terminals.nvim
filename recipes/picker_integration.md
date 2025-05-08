# Recipes: Integrating with Snacks.nvim

This document provides examples of how to integrate `ai-terminals.nvim` with the [snacks.nvim](https://github.com/folke/snacks.nvim) plugin for enhanced workflows, such as adding files selected in a picker or sending grep results directly to an AI agent like Aider.

## 🤝 Integrating with a File Picker

You can configure `snacks.nvim` to easily add files selected in its pickers (like `files` or `git_status`) to the Aider chat context using `ai-terminals.nvim`.

Here's an example configuration for your `snacks.nvim` setup:

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)
local snacks = require("snacks")
local ai_terminals = require("ai-terminals") -- Make sure ai-terminals is loaded

-- Helper function to get selected file paths from the picker
local function add_files_from_picker(picker, read_only)
  local selected_items = picker:get_selected_items()
  if not selected_items or #selected_items == 0 then
    vim.notify("No files selected in picker", vim.log.levels.WARN)
    return
  end

  local files_to_add = {}
  for _, item in ipairs(selected_items) do
    -- Assuming item.filename holds the full path
    if item.filename then
      table.insert(files_to_add, item.filename)
    end
  end

  if #files_to_add > 0 then
    ai_terminals.aider_add_files(files_to_add, { read_only = read_only })
  else
    vim.notify("Could not extract filenames from selected items", vim.log.levels.WARN)
  end
end

-- Define actions for Snacks
local actions = {
  aider_add = function(picker)
    add_files_from_picker(picker, false) -- Add normally
  end,
  aider_read_only = function(picker)
    add_files_from_picker(picker, true) -- Add as read-only
  end,
}

-- Configure Snacks sources to use these actions
-- Note: Use <localleader> for picker-specific actions
snacks.setup({
  -- ... your other snacks config ...
  sources = {
    files = {
      -- ... your files source config ...
      actions = {
        ["<localleader>a"] = actions.aider_add,        -- Mnemonic: Add
        ["<localleader>r"] = actions.aider_read_only, -- Mnemonic: Read-only
      },
    },
    git_status = {
      -- ... your git_status source config ...
      actions = {
        ["<localleader>a"] = actions.aider_add,
        ["<localleader>r"] = actions.aider_read_only,
      },
    },
    -- ... other sources ...
  },
})

-- Optional: Add keymaps to open Snacks with these sources
-- vim.keymap.set("n", "<leader>pf", function() snacks.show("files") end, { desc = "Pick Files (Snacks)" })
-- vim.keymap.set("n", "<leader>pg", function() snacks.show("git_status") end, { desc = "Pick Git Status (Snacks)" })
```

This setup defines two actions, `aider_add` and `aider_read_only`, which use the helper function `add_files_from_picker` to collect selected file paths from the picker and pass them to `require("ai-terminals").aider_add_files`. Keymaps using `<localleader>` are then added to specific picker sources (like `files` and `git_status`) to trigger these actions within the picker window.

## 🔍 Sending Grep Results to Aider

Similarly, you can configure Snacks to send selected lines from a grep search directly to the Aider terminal.

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)
local snacks = require("snacks")
local ai_terminals = require("ai-terminals") -- Ensure ai-terminals is loaded

-- Helper function to send selected grep lines to Aider
local function send_search_results_to_aider(picker)
  local selected_items = picker:get_selected_items()
  if not selected_items or #selected_items == 0 then
    vim.notify("No lines selected in picker", vim.log.levels.WARN)
    return
  end

  local lines_to_send = {}
  for _, item in ipairs(selected_items) do
    -- Assuming item.text holds the grep line content
    if item.text then
      table.insert(lines_to_send, item.text)
    end
  end

  if #lines_to_send > 0 then
    -- Send the concatenated lines to the *active* or *last used* Aider
    -- terminal. Note: This uses the generic 'send_term' function.
    ai_terminals.send_term("aider", table.concat(lines_to_send, "\n"))
    -- Optionally focus the aider terminal after sending
    -- ai_terminals.focus()
  else
    vim.notify("Could not extract text from selected items", vim.log.levels.WARN)
  end
end

-- Define an action for sending search results
local actions = {
  aider_search = function(picker)
    send_search_results_to_aider(picker)
  end,
  -- Include your aider_add and aider_read_only actions from the previous
  -- example if needed
  aider_add = function(picker)
    -- Placeholder: Define or require the add_files_from_picker helper
    -- add_files_from_picker(picker, false)
  end,
  aider_read_only = function(picker)
    -- Placeholder: Define or require the add_files_from_picker helper
    -- add_files_from_picker(picker, true)
  end,
}

-- Configure the grep source in Snacks
-- Note: Use <localleader> for picker-specific actions
snacks.setup({
  -- ... your other snacks config ...
  sources = {
    grep = {
      -- ... your grep source config ...
      actions = {
        ["<localleader>s"] = actions.aider_search, -- Mnemonic: Send Search
      },
    },
    -- Include your files and git_status sources with their actions here
    files = {
      actions = {
        ["<localleader>a"] = actions.aider_add,
        ["<localleader>r"] = actions.aider_read_only,
      },
    },
    git_status = {
      actions = {
        ["<localleader>a"] = actions.aider_add,
        ["<localleader>r"] = actions.aider_read_only,
      },
    },
  },
})

-- Optional: Add a keymap to open the grep source
-- vim.keymap.set("n", "<leader>ps", function() snacks.show("grep") end, { desc = "Pick Grep (Snacks)" })

-- Example of overriding default grep options if needed
-- local overrides = {
--   grep = {
--     cmd = "rg",
--     args = function(opts)
--       return { "--vimgrep", "--no-heading", "--smart-case", opts.query }
--     end,
--     -- Add your actions here as well if overriding the whole source table
--     actions = {
--       ["<localleader>s"] = actions.aider_search,
--     },
--   },
-- }
-- snacks.setup(vim.tbl_deep_extend("force", snacks.config.sources or {}, overrides))
```

This adds a `send_search_results_to_aider` helper function that extracts the text lines from the selected items in the picker (typically grep results) and sends them concatenated together to the Aider terminal using `require("ai-terminals").send_term`. An `aider_search` action is defined to use this helper, and a keymap (`<localleader>s`) is added to the `grep` source to trigger this action within the picker.

💡 **Tip:** You can use `<Tab>` in the Snacks picker to select multiple items (files or grep lines) one by one, or `<C-a>` (Control-A) to select *all* visible items. When you then use the `<localleader>a`, `<localleader>r`, or `<localleader>s` keymaps within the picker, all selected items will be processed and sent to Aider at once!
