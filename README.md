# 🤖 AI Terminals Neovim Plugin

This plugin **seamlessly integrates any widespread and state-of-the-art command-line (CLI) AI coding agents** into Neovim. It provides a unified workflow for interacting with AI assistants directly within your editor, **eliminating the need for proprietary tools or separate applications**.

## ✨ Features

### ⚙️ Generic Features (Works with any terminal-based AI agent)

* **🔌 Configurable Terminal Integration:** Define and manage terminals for various
  AI CLI tools (e.g., Claude, Goose, Aider, custom scripts) through a simple
  configuration table. Uses `Snacks` for terminal window management.
* **🔄 Diff View:** Compare the changes made by the AI agent since the last sync
  with the current state of your project files. A performant backup directory
  is created (using `rsync` for efficient and reliable synchronization) when you
  first open an AI terminal in a session. This backup persists even after
  closing Neovim. The *next* time you open an AI terminal (e.g., using
  `aider_terminal()`), the backup directory is *synced* with the current project
  state using `rsync`, effectively resetting the diff
  base to the state *before* the sync. The `diff_changes()` command finds
  differing files between the current project state and the *most recently
  synced* backup. These differing files are then opened in Neovim's standard
  diff view across multiple tabs. You can use standard diff commands like
  `:diffget` and `:diffput` to
  manage changes (see `:help diff`). The `close_diff()` command closes these
  diff tabs and removes the buffers associated with the temporary backup files
  (i.e., non-local files) from Neovim's buffer list.
* **🔃 Automatic File Reloading:** When you switch focus away from the AI terminal
  window, all listed buffers in Neovim are checked for modifications and
  reloaded if necessary, ensuring you see the latest changes made by the AI.
* **📋 Send Visual Selection:** Send the currently selected text (visual mode) to the AI terminal, automatically wrapped in a markdown code block with the file path and language type included.
* **🩺 Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the current buffer or visual selection to the AI terminal, formatted with severity, line/column numbers, messages, and the corresponding source code lines.
* **🚀 Run Command and Send Output:** Execute an arbitrary shell command and send its standard output along with the exit code to the active AI terminal. This is useful for running tests, linters, or other tools and feeding the results directly to the AI.

### 🔥 Aider Specific Features

While the generic features work well with Aider, this plugin includes additional helpers specifically for Aider:

* **➕ Add Files:** Quickly add the current file or a list of files to the Aider chat context using `/add` or `/read-only`.
* **💬 Add Comments:** Insert comments above the current line with a custom prefix (e.g., `AI!`, `AI?`). This action automatically saves the file and can optionally start the Aider terminal if it's not already running.

## ⚠️ Prerequisites

This plugin integrates with existing command-line AI tools. You need to install the specific tools you want to use *before* configuring them in this plugin.

Here are links to some of the tools mentioned in the default configuration:

* **Aider:** [Aider](https://github.com/paul-gauthier/aider)
* **Claude Code:** [Claude Code](https://github.com/anthropics/claude-code)
* **Goose CLI:** [Goose](https://github.com/pressly/goose)

Make sure these (or your chosen alternatives) are installed and accessible in your system's `PATH`.

## 🔗 Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal window management. 🍬

## 🔧 Configuration

You can optionally configure the plugin using the `setup` function. This allows you to define your own terminals or override the default commands and settings.

**Note:** Calling `setup()` is only necessary if you want to customize the default configuration (e.g., change terminal commands, window dimensions, or the default position). The core functionality, including autocommands for file reloading and backup syncing, works out-of-the-box without calling `setup()`.

```lua
-- In your Neovim configuration (e.g., lua/plugins/ai-terminals.lua)
-- Only call setup if you need to customize defaults:
require("ai-terminals").setup({
  terminals = {
    -- Override the default aider command
    aider = {
      cmd = "aider --dark-mode --no-auto-commits",
    },
    -- Add a new custom terminal
    my_custom_ai = {
      cmd = "/path/to/my/ai/script --interactive",
    },
    -- Keep other defaults like 'goose', 'claude', 'aichat' unless overridden
  },
  -- Override default window dimensions (optional)
  window_dimensions = {
    float = { width = 0.9, height = 0.9 }, -- Make float windows slightly smaller
    bottom = { width = 1.0, height = 0.4 }, -- Make bottom windows wider and shorter
    -- Keep other position defaults ('top', 'left', 'right')
  },
  -- Set the default window position if none is specified (default: "float")
  default_position = "bottom", -- Example: Make terminals open at the bottom by default
})
```

The `cmd` field for each terminal can be a `string` or a `function` that returns a string. Using a function allows the command to be generated dynamically *just before* the terminal is opened (e.g., to check `vim.o.background` at invocation time).

### 🚀 Example Usage

#### Using `lazy.nvim`

##### ⌨️ Basic Keymaps

```lua
-- lazy.nvim plugin specification
return {
  {
    "aweis89/ai-terminals.nvim",
    -- Example opts using functions for dynamic command generation (matches plugin defaults)
    opts = {
      terminals = {
        goose = {
          cmd = function()
            return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)
          end,
        },
        claude = {
          cmd = function()
            return string.format("claude config set -g theme %s && claude", vim.o.background)
          end,
        },
        aider = {
          cmd = function()
            return string.format("aider --watch-files --%s-mode", vim.o.background)
          end,
        },
        aichat = {
          cmd = function()
            return string.format(
              "AICHAT_LIGHT_THEME=%s aichat -r %%functions%% --session",
              tostring(vim.o.background == "light") -- Convert boolean to string "true" or "false"
            )
          end,
        },
        -- Example of a simple string command
        -- my_simple_ai = { cmd = "my_ai_tool --interactive" },
      },
    },
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
      -- Example Keymaps (using default terminal names: 'claude', 'goose', 'aider')
      -- Claude Keymaps
      {
        "<leader>atc", -- Mnemonic: AI Terminal Claude
        function()
          require("ai-terminals").toggle("claude")
        end,
        desc = "Toggle Claude terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adc", -- Mnemonic: AI Diagnostics Claude
        function()
          require("ai-terminals").send_diagnostics("claude")
        end,
        desc = "Send diagnostics to Claude",
        mode = { "n", "v" }, -- Allow sending buffer or selection diagnostics
      },
      -- Goose Keymaps
      {
        "<leader>atg", -- Mnemonic: AI Terminal Goose
        function()
          require("ai-terminals").toggle("goose")
        end,
        desc = "Toggle Goose terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adg", -- Mnemonic: AI Diagnostics Goose
        function()
          require("ai-terminals").send_diagnostics("goose")
        end,
        desc = "Send diagnostics to Goose",
        mode = { "n", "v" },
      },
      -- Aider Keymaps
      {
        "<leader>ata", -- Mnemonic: AI Terminal Aider
        function()
          require("ai-terminals").toggle("aider")
        end,
        desc = "Toggle Aider terminal (sends selection in visual mode)",
        mode = { "n", "v" },
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
          -- add current file
          require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") })
        end,
        desc = "Add current file to Aider",
      },
      {
        "<leader>ada", -- Mnemonic: AI Diagnostics Aider
        function()
          require("ai-terminals").send_diagnostics("aider")
        end,
        desc = "Send diagnostics to Aider",
        mode = { "n", "v" },
      },
      -- Example: Run a command and send output to a specific terminal (e.g., Aider)
      {
        "<leader>ar", -- Mnemonic: AI Run command
        function()
          -- Prompt user for command
          require("ai-terminals").send_command_output("aider")
          -- Or use a fixed command like:
          -- require("ai-terminals").send_command_output("aider", "make test")
        end,
        desc = "Run command (prompts) and send output to Aider terminal",
      },
    },
  },
}
```

#### Using `packer.nvim`

If you are using `packer.nvim`, you only need to call the `setup` function in your configuration if you want to customize the defaults.

```lua
-- In your Neovim configuration (e.g., lua/plugins.lua or similar)
use({
  "aweis89/ai-terminals.nvim",
  requires = { "folke/snacks.nvim" }, -- Make sure dependencies are loaded
  config = function()
    -- Only call setup if you need to customize defaults:
    require("ai-terminals").setup({
      -- Your custom configuration goes here (optional)
      terminals = {
        aider = {
          cmd = "aider --dark-mode --no-auto-commits", -- Example override
        },
        -- Add other terminals or keep defaults
      },
    })

    -- Define your keymaps here or in a separate keymap file

    -- Diff Tools
    vim.keymap.set("n", "<leader>dvo", function() require("ai-terminals").diff_changes() end, { desc = "Show diff of last changes made" })
    vim.keymap.set("n", "<leader>dvc", function() require("ai-terminals").close_diff() end, { desc = "Close all diff views (and wipeout buffers)" })

    -- Claude Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atc", function() require("ai-terminals").toggle("claude") end, { desc = "Toggle Claude terminal (sends selection in visual mode)" })
    vim.keymap.set({"n", "v"}, "<leader>adc", function() require("ai-terminals").send_diagnostics("claude") end, { desc = "Send diagnostics to Claude" })

    -- Goose Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atg", function() require("ai-terminals").toggle("goose") end, { desc = "Toggle Goose terminal (sends selection in visual mode)" })
    vim.keymap.set({"n", "v"}, "<leader>adg", function() require("ai-terminals").send_diagnostics("goose") end, { desc = "Send diagnostics to Goose" })

    -- Aider Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ata", function() require("ai-terminals").toggle("aider") end, { desc = "Toggle Aider terminal (sends selection in visual mode)" })
    vim.keymap.set("n", "<leader>ac", function() require("ai-terminals").aider_comment("AI!") end, { desc = "Add 'AI!' comment above line" })
    vim.keymap.set("n", "<leader>aC", function() require("ai-terminals").aider_comment("AI?") end, { desc = "Add 'AI?' comment above line" })
    vim.keymap.set("n", "<leader>al", function() require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") }) end, { desc = "Add current file to Aider" })
    vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

    -- Example: Run a command and send output to a specific terminal (e.g., Aider)
    vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider") end, { desc = "Run command (prompts) and send output to Aider terminal" })
    -- Or use a fixed command like:
    -- vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider", "make test") end, { desc = "Run 'make test' and send output to Aider terminal" })
  end,
})
```

#### 🤝 Integrating with a File Picker (e.g., snacks.nvim)

You can integrate the `aider_add_files` function with file pickers like `snacks.nvim` to easily add selected files to the Aider context.

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
    table.insert(files_to_add, item.file)
  end
  -- Assuming 'ai-terminals' is the require path
  require("ai-terminals").aider_add_files(files_to_add, opts)
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

This setup defines two actions, `aider_add` and `aider_read_only`, which use the helper function `add_files_from_picker` to collect selected file paths from the picker and pass them to `require("ai-terminals").aider_add_files`. Keymaps are then added to specific picker sources (like `files` and `git_status`) to trigger these actions.
