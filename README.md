# AI Terminals Neovim Plugin

This plugin integrates any terminal/CLI-based AI agent into Neovim, providing a seamless workflow for interacting with AI assistants directly within your editor.

## Features

### Generic Features (Works with any terminal-based AI agent)

* **Terminal Integration:** Easily open and manage terminals running your
  preferred AI CLI tool (e.g., Claude, Goose, Aider, custom scripts) using
  `Snacks` for terminal management.
* **Diff View:** Compare the changes made by the AI agent in the last session
  with the current state of your project files. A performant backup (using
  `rsync`) of your project is created when you first open an AI terminal in a
  session. This backup persists even after closing Neovim. The *next* time you
  open an AI terminal (e.g., using `aider_terminal()`), a *new* backup is
  created, resetting the diff base. The `diff_changes()` command finds differing
  files between the current project state and the *most recent* backup. These
  differing files are then opened in Neovim's standard diff view across multiple
  tabs. You can use standard diff commands like `:diffget` and `:diffput` to
  manage changes (see `:help diff`). The `close_diff()` command closes these
  diff tabs and removes the buffers associated with the temporary backup files
  (i.e., non-local files) from Neovim's buffer list.
* **Automatic File Reloading:** When you switch focus away from the AI terminal
  window, all listed buffers in Neovim are checked for modifications and
  reloaded if necessary, ensuring you see the latest changes made by the AI.
* **Send Visual Selection:** Send the currently selected text (visual mode) to the AI terminal, automatically wrapped in a markdown code block with the file path and language type included.
* **Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the current buffer or visual selection to the AI terminal, formatted with severity, line/column numbers, messages, and the corresponding source code lines.
* **Run Command and Send Output:** Execute an arbitrary shell command and send its standard output along with the exit code to the active AI terminal. This is useful for running tests, linters, or other tools and feeding the results directly to the AI.

### Aider Specific Features

While the generic features work well with Aider, this plugin includes additional helpers specifically for Aider:

* **Add Files:** Quickly add the current file or a list of files to the Aider chat context using `/add` or `/read-only`.
* **Add Comments:** Insert comments above the current line with a custom prefix (e.g., `AI!`, `AI?`). This action automatically saves the file and can optionally start the Aider terminal if it's not already running.
* **Multiline Input Handling:** Automatically wraps text (like visual selections or diagnostics) containing newlines using terminal bracketed paste mode (`ESC[200~...ESC[201~`). This ensures reliable multiline input for most modern terminal applications.

## Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal window management.

### Example usage with lazy.nvim

#### Basic Keymaps

```lua
-- lazy.nvim plugin specification
return {
  {
    "aweis89/ai-terminals.nvim",
    event = "VeryLazy", -- Load when needed
    keys = {
      -- Diff Tools
      {
        "<leader>dvo",
        function()
          require("ai-terminals").diff_changes()
        end,
        desc = "Show diff of last changes made",
      },
      {
        "<leader>dvc",
        function()
          require("ai-terminals").close_diff()
        end,
        desc = "Close all diff views (and wipeout buffers)",
      },
      -- Claude Keymaps
      {
        "<leader>ass",
        function()
          require("ai-terminals").claude_toggle()
          -- Note: claude_toggle() returns the terminal instance.
          -- If you need to send data immediately after toggling,
          -- capture the return value like in the 'send selection' keymap.
        end,
        desc = "Toggle Claude terminal",
      },
      {
        "<leader>ass", -- Same keybinding, but in visual mode
        function()
          local selection = require("ai-terminals").get_visual_selection_with_header() or ""
          -- Ensure the terminal is open and get its instance
          local term = require("ai-terminals").claude_toggle()
          -- Send the selection to the specific terminal instance
          require("ai-terminals").send(selection, { term = term })
        end,
        desc = "Send selection to Claude",
        mode = { "v" },
      },
      {
        "<leader>asd",
        function()
          local diagnostics = require("ai-terminals").diagnostics()
          local term = require("ai-terminals").claude_toggle() -- Ensure terminal is open
          require("ai-terminals").send(diagnostics, { term = term })
        end,
        desc = "Send diagnostics to Claude",
        mode = { "v" },
      },
      -- Goose Keymaps
      {
        "<leader>agg",
        function()
          require("ai-terminals").goose_toggle()
        end,
        desc = "Toggle Goose terminal",
      },
      {
        "<leader>agg", -- Same keybinding, visual mode
        function()
          local selection = require("ai-terminals").get_visual_selection_with_header() or ""
          local term = require("ai-terminals").goose_toggle()
          require("ai-terminals").send(selection, { term = term })
        end,
        desc = "Send selection to Goose",
        mode = { "v" },
      },
      {
        "<leader>agd",
        function()
          local diagnostics = require("ai-terminals").diagnostics()
          local term = require("ai-terminals").goose_toggle()
          require("ai-terminals").send(diagnostics, { term = term })
        end,
        desc = "Send diagnostics to Goose",
        mode = { "v" },
      },
      -- Aider Keymaps
      {
        "<leader>aa",
        function()
          require("ai-terminals").aider_toggle()
        end,
        desc = "Toggle Aider terminal",
      },
      {
        "<leader>ac",
        function()
          require("ai-terminals").aider_comment("AI!") -- Adds comment and saves file
        end,
        desc = "Add 'AI!' comment above line",
      },
      {
        "<leader>aC",
        function()
          require("ai-terminals").aider_comment("AI?") -- Adds comment and saves file
        end,
        desc = "Add 'AI?' comment above line",
      },
      {
        "<leader>al",
        function()
          local current_file = vim.fn.expand("%:p")
          -- add_files_to_aider handles toggling the terminal if needed
          require("ai-terminals").add_files_to_aider({ current_file })
        end,
        desc = "Add current file to Aider",
      },
      {
        "<leader>aa", -- Same keybinding, visual mode
        function()
          local selection = require("ai-terminals").get_visual_selection_with_header()
          if selection then -- Check if selection is not nil
            local term = require("ai-terminals").aider_toggle() -- Ensure terminal is open
            require("ai-terminals").send(selection, { term = term })
          else
            vim.notify("No text selected to send to Aider", vim.log.levels.WARN)
          end
        end,
        desc = "Send selection to Aider",
        mode = { "v" },
      },
      {
        "<leader>ad",
        function()
          local diagnostics = require("ai-terminals").diagnostics()
          local term = require("ai-terminals").aider_toggle() -- Ensure terminal is open
          require("ai-terminals").send(diagnostics, { term = term })
        end,
        desc = "Send diagnostics to Aider",
        mode = { "v" },
      },
      -- Example: Run 'make test' and send output to active terminal
      -- Assumes the desired AI terminal is already the active buffer
      {
        "<leader>at",
        function()
          -- Ensure the terminal is open
          -- This command sends output to the *currently active* terminal buffer.
          -- No arg will prompt the user to enter a command
          require("ai-terminals").run_command_and_send_output()
          -- or specify the command directly
          -- require("ai-terminals").run_command_and_send_output("make test")
        end,
        desc = "Run 'make test' and send output to active AI terminal",
      },
    },
  },
}
```

#### Integrating with a File Picker (e.g., snacks.nvim)

You can integrate the `add_files_to_aider` function with file pickers like `snacks.nvim` to easily add selected files to the Aider context.

Here's an example of how you might configure `snacks.nvim` to add actions for sending files to Aider:

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)

-- Helper function to extract files from a snacks picker and send them to aider
---@param picker snacks.Picker
---@param opts? { read_only?: boolean } Options for the command
local function add_files_from_picker(picker, opts)
  local selected = picker:selected({ fallback = true })
  local files_to_add = {}
  for _, item in pairs(selected) do
    if item.file then
      local full_path = vim.fn.fnamemodify(item.file, ":p")
      table.insert(files_to_add, full_path)
    end
  end
  -- Assuming 'ai-terminals' is the name you used in lazy.nvim
  require("ai-terminals").add_files_to_aider(files_to_add, opts)
end

-- Inside the snacks opts function:
local overrides = {
  picker = {
    actions = {
      ["aider_add"] = function(picker)
        picker:close()
        add_files_from_picker(picker) -- Defaults to { read_only = false } -> /add
      end,
      ["aider_read_only"] = function(picker)
        picker:close()
        add_files_from_picker(picker, { read_only = true }) -- Send /read-only
      end,
      -- ... other actions
    },
    sources = {
      -- Add keymaps to relevant pickers (e.g., files, git_status)
      files = {
        win = {
          input = {
            keys = {
              ["<leader><space>a"] = { "aider_add", mode = { "n", "i" } },
              ["<leader><space>A"] = { "aider_read_only", mode = { "n", "i" } },
              -- ... other keys
            },
          },
        },
      },
      git_status = {
         win = {
          input = {
            keys = {
              ["<leader><space>a"] = { "aider_add", mode = { "n", "i" } },
              ["<leader><space>A"] = { "aider_read_only", mode = { "n", "i" } },
              -- ... other keys
            },
          },
        },
      },
      -- ... other sources
    },
  },
}

-- Make sure to merge these overrides with your existing snacks options
-- return vim.tbl_deep_extend("force", opts or {}, overrides)

```

This setup defines two actions, `aider_add` and `aider_read_only`, which use the helper function `add_files_from_picker` to collect selected file paths from the picker and pass them to `require("ai-terminals").add_files_to_aider`. Keymaps are then added to specific picker sources (like `files` and `git_status`) to trigger these actions.
