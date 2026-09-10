-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- Create a unique group name for your custom layout conceals
-- local conceal_group = vim.api.nvim_create_augroup("UserConceal", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "ColorColumn", { link = "CursorLine" })
  end,
})

-- Apply it to the colorscheme already loaded during startup
vim.api.nvim_set_hl(0, "ColorColumn", { link = "CursorLine" })
