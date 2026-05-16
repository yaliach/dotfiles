-- Set leader key to Space
vim.g.mapleader = " "

-- Resize splits
vim.keymap.set("n", "<leader>=", "<C-w>=", { desc = "Equalize splits" })
vim.keymap.set("n", "<leader><left>",  "<C-w><", { desc = "Resize left" })
vim.keymap.set("n", "<leader><right>", "<C-w>>", { desc = "Resize right" })
vim.keymap.set("n", "<leader><up>",    "<C-w>+", { desc = "Resize up" })
vim.keymap.set("n", "<leader><down>",  "<C-w>-", { desc = "Resize down" })

-- Panels
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle File Explorer" })

-- Keep selection after indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = "Indent left and keep selection" })
vim.keymap.set('v', '>', '>gv', { desc = "Indent right and keep selection" })

-- Delete without yanking
vim.keymap.set('n', 'dd', '"_dd', { desc = "Delete line without copying" })
vim.keymap.set('v', 'd', '"_d', { desc = "Delete selection without copying" })
vim.keymap.set('n', 'D', '"_D', { desc = "Delete to end of line without copying" })
vim.keymap.set('n', 'x', '"_x', { desc = "Delete character without copying" })
