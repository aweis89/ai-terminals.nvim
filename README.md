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

## Commands

This plugin exposes several user commands:

*   `:AiderToggle` - Toggle the Aider terminal window.
*   `:AiderComment[!]` - Add an AI comment on the line above the cursor. With `!` adds an `AI!` comment, without adds an `AI` comment. Saves the file.
*   `:AiderCommentAsk` - Add an `AI?` comment on the line above the cursor. Saves the file.
*   `:AiderAdd [files...]` - Add specified files to the Aider session. If no files are specified, the current file is added. Supports file completion.
*   `:AiderReadOnly [files...]` - Add specified files to the Aider session in read-only mode. If no files are specified, the current file is added. Supports file completion.
*   `:AiderAsk [prompt]` - Ask Aider a question using `/ask`. If text is visually selected, it's included after the prompt. If no prompt is given, you'll be prompted to enter one.
*   `:AiderSend [text]` - Send arbitrary text or commands to the Aider terminal. If text is visually selected, it's appended to the command text. Executes the text by adding a newline.
*   `:AiderFixDiagnostics` - Send Neovim diagnostics to Aider for fixing. Works on the current buffer or the visual selection if present.
*   `:AiderRunCommand <shell_command>` - Execute a shell command and send its output and exit code to the Aider terminal. Supports command completion.

*Note:* For commands that interact with the Aider terminal (`:AiderAdd`, `:AiderReadOnly`, `:AiderAsk`, `:AiderSend`, `:AiderFixDiagnostics`, `:AiderRunCommand`), the Aider terminal will be opened automatically if it's not already running.

## Example Usage

### Basic Keymaps (using lazy.nvim)

```lua
-- lazy.nvim plugin specification
return {
  {
    "aweis89/ai-terminals.nvim",
    -- No need for event = "VeryLazy" if you define commands,
    -- as they are registered when the plugin loads.
    -- You might use `cmd = { ... }` if you only want to load on command usage.
    -- Or keep event if you prefer lazy loading and define commands elsewhere.
    -- For simplicity, let's assume it loads reasonably early.
    keys = {
      -- Diff Tools (These still use the module directly)
      {
        "<leader>dvo",
        function() require("ai-terminals").diff_changes() end,
        desc = "[D]iff [V]iew [O]pen Changes",
      },
      {
        "<leader>dvc",
        function() require("ai-terminals").close_diff() end,
        desc = "[D]iff [V]iew [C]lose",
      },

      -- Aider Keymaps (Using Commands)
      { "<leader>aa", "<cmd>AiderToggle<cr>", desc = "[A]ider [A]ctivate/Toggle" },
      { "<leader>ac", "<cmd>AiderComment!<cr>", desc = "[A]ider [C]omment (!)" },
      { "<leader>aC", "<cmd>AiderCommentAsk<cr>", desc = "[A]ider [C]omment (?)" },
      { "<leader>al", "<cmd>AiderAdd<cr>", desc = "[A]ider [L]oad Current File" },
      -- Example: Add all lua files in cwd
      -- { "<leader>aL", "<cmd>AiderAdd *.lua<cr>", desc = "[A]ider [L]oad Lua Files" },
      {
        "<leader>aa", -- Same keybinding, visual mode -> Send selection
        ":'<,'>AiderSend<cr>",
        mode = "v",
        desc = "[A]ider [A]dd Visual Selection",
      },
      {
        "<leader>ad", -- Send diagnostics (buffer)
        "<cmd>AiderFixDiagnostics<cr>",
        desc = "[A]ider [D]iagnostics (Buffer)",
      },
      {
        "<leader>ad", -- Send diagnostics (visual)
        ":'<,'>AiderFixDiagnostics<cr>",
        mode = "v",
        desc = "[A]ider [D]iagnostics (Visual)",
      },
      {
        "<leader>ak", -- Ask Aider (prompt)
        "<cmd>AiderAsk<cr>",
        desc = "[A]ider As[k] (Prompt)",
      },
      {
        "<leader>ak", -- Ask Aider (visual)
        ":'<,'>AiderAsk<cr>",
        mode = "v",
        desc = "[A]ider As[k] (Visual)",
      },
      -- Example: Run 'make test' and send output to Aider
      {
        "<leader>at",
        "<cmd>AiderRunCommand make test<cr>",
        desc = "[A]ider Run [T]est",
      },

      -- You can still define keymaps for other terminals like Claude/Goose
      -- using the direct module functions if needed:
      {
        "<leader>gg", -- Goose Toggle
        function() require("ai-terminals").goose_toggle() end,
        desc = "[G]oose Toggle",
      },
      {
        "<leader>gg", -- Goose Send Selection
        function()
          local selection = require("ai-terminals").get_visual_selection_with_header() or ""
          local term = require("ai-terminals").goose_toggle() -- Ensure open
          require("ai-terminals").send(selection, { term = term })
        end,
        mode = "v",
        desc = "[G]oose Send Selection",
      },
       {
        "<leader>cc", -- Claude Toggle
        function() require("ai-terminals").claude_toggle() end,
        desc = "[C]laude Toggle",
      },
      {
        "<leader>cc", -- Claude Send Selection
        function()
          local selection = require("ai-terminals").get_visual_selection_with_header() or ""
          local term = require("ai-terminals").claude_toggle() -- Ensure open
          require("ai-terminals").send(selection, { term = term })
        end,
        mode = "v",
        desc = "[C]laude Send Selection",
      },
    },
  },
}
```

### Integrating with a File Picker (e.g., snacks.nvim)

You can integrate the `:AiderAdd` and `:AiderReadOnly` commands with file pickers like `snacks.nvim` to easily add selected files to the Aider context.

Here's an example of how you might configure `snacks.nvim` to add actions for sending files to Aider:

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

  if #files_to_add > 0 then
    local command = opts and opts.read_only and "AiderReadOnly" or "AiderAdd"
    -- Escape file paths for the command line
    local escaped_files = vim.tbl_map(function(f) return vim.fn.fnameescape(f) end, files_to_add)
    local cmd_string = string.format("%s %s", command, table.concat(escaped_files, " "))
    vim.cmd(cmd_string)
  else
    vim.notify("No files selected from picker.", vim.log.levels.WARN)
  end
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
