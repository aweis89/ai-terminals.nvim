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
  manage changes (see `:help diff`).
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
* **Multiline Input Handling:** Automatically formats text (like visual selections or diagnostics) using Aider's specific `{EOL ... EOL}` syntax for reliable multiline input.

## Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal window management.

### Example usage with lazy.nvim

#### Basic Keymaps

```lua
local plug = function()
  return require("ai-terminals")
end

return {
  {
    "aweis89/ai-terminals.nvim",
    event = "VeryLazy",
    keys = {
      -- Diff Tools
      {
        "<leader>dvo",
        function()
          plug().diff_changes()
        end,
        desc = "Show diff of last changes made",
      },
      {
        "<leader>dvc",
        function()
          plug().close_diff()
        end,
        desc = "Close all diff views (and wipeout buffers)",
      },
      -- Claude Keymaps
      {
        "<leader>ass",
        function()
          plug().claude_terminal()
          -- or start a custom terminal instead:
          -- plug().ai_terminal("my-cli --arg")
        end,
        desc = "Toggle Claude terminal",
      },
      {
        "<leader>ass",
        function()
          plug().send_selection(plug().claude_terminal)
        end,
        desc = "Send selection to Claude",
        mode = { "v" },
      },
      {
        "<leader>asd",
        function()
          local diagnostics = plug().diagnostics()
          plug().claude_terminal()
          plug().send(diagnostics)
        end,
        desc = "Send diagnostics to Claude",
        mode = { "v" },
      },
      -- Goose Keymaps
      {
        "<leader>agg",
        function()
          plug().goose_terminal()
        end,
        desc = "Toggle Goose terminal",
      },
      {
        "<leader>agg",
        function()
          local selection = plug().get_visual_selection_with_header()
          plug().goose_terminal()
          plug().send(selection)
        end,
        desc = "Send selection to Goose",
        mode = { "v" },
      },
      {
        "<leader>agd",
        function()
          local diagnostics = plug().diagnostics()
          plug().goose_terminal()
          plug().send(diagnostics)
        end,
        desc = "Send diagnostics to Goose",
        mode = { "v" },
      },
      -- Aider Keymaps
      {
        "<leader>aa",
        function()
          plug().aider_terminal()
        end,
        desc = "Toggle Aider terminal",
      },
      {
        "<leader>ac",
        function()
          plug().aider_comment("AI!")
        end,
        desc = "Add comment above line",
      },
      {
        "<leader>aC",
        function()
          plug().aider_comment("AI?")
        end,
        desc = "Add comment above line",
      },
      {
        "<leader>al",
        function()
          local current_file = vim.fn.expand("%:p")
          plug().aider_terminal()
          plug().send("/add " .. current_file .. "\n")
        end,
        desc = "Add file to Aider",
      },
      {
        "<leader>aa",
        function()
          local selection = plug().get_visual_selection_with_header()
          plug().aider_terminal()
          plug().send(plug().aider_multiline(selection))
          vim.api.nvim_feedkeys("i", "n", false)
        end,
        desc = "Send selection to Aider",
        mode = { "v" },
      },
      {
        "<leader>ad",
        function()
          local diagnostics = plug().diagnostics()
          plug().aider_terminal()
          plug().send(plug().aider_multiline(diagnostics))
        end,
        desc = "Send diagnostics to Aider",
        mode = { "v" },
      },
      -- Example: Run 'make test' and send output to active terminal
      {
        "<leader>at",
        function()
          plug().run_command_and_send_output("make test")
        end,
        desc = "Run 'make test' and send output to AI terminal",
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
