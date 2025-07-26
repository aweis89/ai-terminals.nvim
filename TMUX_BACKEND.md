# Tmux Backend Support

This plugin now supports an optional tmux backend using [`tmux-toggle-popup.nvim`](https://github.com/cenk1cenk2/tmux-toggle-popup.nvim) instead of the default Snacks terminal.

## Requirements

1. **tmux session**: You must be running inside a tmux session
2. **tmux-toggle-popup plugin**: Install the tmux plugin as described in [their README](https://github.com/loichyan/tmux-toggle-popup)
3. **tmux-toggle-popup.nvim**: Install the Neovim plugin

## Installation

### 1. Install tmux plugin

Add to your `tmux.conf`:

```tmux
# install with tpm
set -g @plugin "loichyan/tmux-toggle-popup"

# Configure popup settings
set -g @popup-toggle-mode 'force-close'
bind C-a run "#{@popup-toggle} --name scratch -Ed'#{pane_current_path}' -w95% -h95%"

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.config/tmux/plugins/tpm/tpm'
```

### 2. Install Neovim plugin

With lazy.nvim:

```lua
{
  "cenk1cenk2/tmux-toggle-popup.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
```

## Configuration

To enable the tmux backend, set `backend = "tmux"` in your ai-terminals configuration:

```lua
require("ai-terminals").setup({
  backend = "tmux", -- Use tmux instead of snacks terminal
  
  -- Optional tmux-specific configuration
  tmux = {
    width = 0.9, -- 90% of terminal width
    height = 0.9, -- 90% of terminal height
    flags = {
      close_on_exit = true, -- Close popup when command exits
      start_directory = function() return vim.fn.getcwd() end, -- Start in current working directory
    },
    -- Uncomment to add global toggle key for all tmux popups
    -- toggle = {
    --   key = "-n F1", -- Global F1 key to toggle
    --   mode = "force-close"
    -- },
  },
  
  -- Your existing configuration...
  terminals = {
    aider = {
      cmd = "aider --watch-files --dark-mode",
    },
    -- ... other terminals
  },
})
```

## Usage

Once configured, all terminal functions work the same way:

```lua
-- Toggle aider terminal (now uses tmux popup)
require("ai-terminals").toggle("aider")

-- Send text to terminal
require("ai-terminals").send_term("aider", "Hello from tmux!")

-- All other functions work as before
```

## Differences from Snacks Backend

### Advantages
- **Native tmux integration**: Terminals run in proper tmux sessions
- **Better resource management**: Terminals survive Neovim crashes/restarts
- **Tmux features**: Access to all tmux functionality (copy mode, etc.)
- **Multiple sessions**: Can run different terminals in separate tmux sessions

### Limitations
- **No vim buffers**: Tmux terminals don't create vim buffers, so some buffer-specific features may not work
- **Requires tmux**: Only works when running inside a tmux session
- **Different focus handling**: Tmux handles focus differently than vim windows
- **Limited integration**: Some vim-specific features (like terminal keymaps) may have limited functionality

## Fallback Strategy

You can implement a fallback strategy like this:

```lua
local function setup_ai_terminals()
  local backend = "snacks" -- Default
  
  -- Use tmux backend if available and in tmux session
  if vim.env.TMUX then
    local ok, _ = pcall(require, "tmux-toggle-popup")
    if ok then
      backend = "tmux"
    end
  end
  
  require("ai-terminals").setup({
    backend = backend,
    -- ... rest of config
  })
end

setup_ai_terminals()
```

This will automatically use the tmux backend when available and fall back to snacks otherwise.