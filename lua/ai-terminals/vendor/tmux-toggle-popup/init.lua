local M = {
  setup = require("ai-terminals.vendor.tmux-toggle-popup.config").setup,
  open = require("ai-terminals.vendor.tmux-toggle-popup.api").open,
  save = require("ai-terminals.vendor.tmux-toggle-popup.api").save,
  save_all = require("ai-terminals.vendor.tmux-toggle-popup.api").save_all,
  kill = require("ai-terminals.vendor.tmux-toggle-popup.api").kill,
  kill_all = require("ai-terminals.vendor.tmux-toggle-popup.api").kill_all,
  format = require("ai-terminals.vendor.tmux-toggle-popup.api").format,
  is_tmux = require("ai-terminals.vendor.tmux-toggle-popup.utils").is_tmux,
}

return M
