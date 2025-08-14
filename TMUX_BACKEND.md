# Tmux Backend Support

This plugin now supports an optional tmux backend using [`tmux-toggle-popup.nvim`](https://github.com/cenk1cenk2/tmux-toggle-popup.nvim) instead of the default Snacks terminal.

## Requirements

1. **tmux session**: You must be running inside a tmux session
2. **tmux-toggle-popup plugin**: Install the tmux plugin as described in [their README](https://github.com/loichyan/tmux-toggle-popup)

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

## Configuration

The tmux backend is **automatically enabled** when running Neovim inside a tmux session. You can also explicitly set the backend:

```lua
require("ai-terminals").setup({
  backend = "tmux", -- Explicitly use tmux backend (auto-detected if in tmux)
  
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

## Popup Sizing

The tmux backend uses simple width and height parameters instead of positions (since tmux popups are always centered):

```lua
require("ai-terminals").setup({
  backend = "tmux",
  tmux = {
    width = 0.8,   -- 80% of terminal width (0.0-1.0)
    height = 0.6,  -- 60% of terminal height (0.0-1.0)
  },
})
```

**Note**: Position arguments are ignored with the tmux backend - all popups are centered with the configured width/height.

## Usage Notes

### Hiding/Closing Popups
- **Prefix + d** (usually Ctrl+b d) - Hide the popup without closing the process
- **Toggle functions** - When using `toggle()` in visual mode, it will open the popup and send selected text, but won't close existing popups (closing is controlled by tmux keymappings)
- **Exit command** - Type `exit` or use Ctrl+C to close the command and popup

### Tmux Control
Since popups run in tmux sessions, they're controlled by tmux rather than Neovim:
- Popups persist when Neovim exits
- Use tmux commands to manage popup lifecycle
- Configure tmux toggle keys for convenient popup control

## Differences from Snacks Backend

### Advantages
- **Native tmux integration**: Terminals run in proper tmux sessions
- **Better resource management**: Terminals survive Neovim crashes/restarts
- **Tmux features**: Access to all tmux functionality (copy mode, etc.)
- **Multiple sessions**: Can run different terminals in separate tmux sessions
- **Simple configuration**: Direct width/height control

### Limitations
- **No vim buffers**: Tmux terminals don't create vim buffers, so some buffer-specific features may not work
- **Requires tmux**: Only works when running inside a tmux session
- **Different focus handling**: Tmux handles focus differently than vim windows
- **Limited integration**: Some vim-specific features (like terminal keymaps) may have limited functionality
- **No positional control**: Tmux popups are always centered - no positioning like vim splits
- **Position arguments ignored**: `toggle("aider", "right")` behaves same as `toggle("aider")`

## Backend Selection

The plugin automatically chooses the appropriate backend:

- **In tmux session**: Uses tmux backend automatically  
- **Outside tmux**: Uses snacks backend automatically
- **Override**: Set `backend = "snacks"` to force snacks even in tmux

```lua
-- Force snacks backend even in tmux
require("ai-terminals").setup({
  backend = "snacks",
  -- ... rest of config
})
```
