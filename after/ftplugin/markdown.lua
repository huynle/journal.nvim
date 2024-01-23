-- local util = require("huy.util")
local util = require("journal.utils")
local journal_zk = require("autozk.helpers")
-- local wk = require("which-key")
-- local bufnr = vim.api.nvim_get_current_buf()
-- local log = require("huy.util.log")

-- Set 'iskeyword' specifically for Markdown files
-- This allows #hastag-to-include-dash
vim.api.nvim_exec(
	[[
  autocmd FileType markdown setlocal iskeyword+=-
]],
	false
)

---- BUFFER local settings
vim.bo.shiftwidth = 2
-- # dont let line run too long. wrap them
vim.bo.textwidth = 99

---- WINDOW local settings
vim.wo.concealcursor = "c"
-- spell is set up events.vim, for now.. it should be in this file
vim.wo.spell = false

util.augroup("huyMarkdown", {

	-- -- " allow all wiki notes to close with C-c
	-- { "BufRead,BufNewFile", "*/journal/*.md", "nnoremap <buffer><silent> <C-c> :close!<CR>" },
	-- { "BufRead,BufNewFile", "*/journal/*.md", "nnoremap <buffer><silent> q :close!<CR>" },

	-- switching back and forth between concealing
	{ "InsertEnter", "*", "setlocal conceallevel=0" },
	{ "BufEnter,InsertLeave", "*", "setlocal conceallevel=2" },

	-- when leaving a window for markdown, save it
	-- { "CursorHold", "*", "update" },

	-- " run hugo post maintenance
	{ "BufWritePre", "*/docs/*.md", "silent! HugoHelperLastmodIsNow" },
})

-- loads BEFORE global plugins, so it might get overridden by ther plugins

vim.g.markdown_lua_loaded = 1

-- util.nnoremap("\\d", "<cmd>put =strftime(\"%Y-%m-%d\")<CR>")
local function link_surround()
	-- local mode = vim.fn.mode()
	-- local bufnr, off, len, line, idx
	-- local csrow, cscol, cerow, cecol

	local line, idx, len, csrow, off = util.get_interested_item()

	-- Stich selection with link into original line and replace it.
	local new = vim.fn.strcharpart(line, 0, idx)
		.. "["
		.. vim.fn.strcharpart(line, idx, len)
		.. "]()"
		.. vim.fn.strcharpart(line, idx + len)
	vim.fn.setline(csrow, new)
	vim.fn.setpos(".", { bufnr, csrow, idx + len + 4, off })
	vim.cmd.startinsert()
end

-- Set key-mappings.
local opts = { noremap = true, buffer = 0 }
vim.keymap.set("n", "<M-Return>", link_surround, opts)
vim.keymap.set("x", "<M-Return>", link_surround, opts)

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
	.. (vim.b.undo_ftplugin ~= nil and " | " or "")
	.. "sil! nunmap <buffer> <M-Return>"
	.. " | sil! xunmap <buffer> <M-Return>"

vim.g["enable_auto_zk"] = false

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	group = vim.api.nvim_create_augroup("auto_zk", {}),
	pattern = "*/docs/*.md",
	callback = function()
		vim.cmd("AutoZ")
	end,
})

local function toggle_auto_zk()
	vim.g["enable_auto_zk"] = not vim.g["enable_auto_zk"]
	vim.print("auto zk: " .. tostring(vim.g["enable_auto_zk"]))
end

-- Add the key mappings only for Markdown files in a zk notebook.
if require("zk.util").notebook_root(vim.fn.expand("%:p")) ~= nil then
	vim.keymap.set("n", "<CR>", function()
		journal_zk.jump_to_tag_definition_page()
	end, opts)

	vim.keymap.set("v", "<CR>", function()
		journal_zk.jump_to_tag_definition_page()
	end, opts)

	vim.keymap.set("n", "<leader>uz", function()
		toggle_auto_zk()
	end, opts)

	vim.keymap.set("n", "<leader>zz", function()
		vim.cmd("AutoZ")
	end, opts)
else
	util.log("CANNOT load zk for markdown", nil, "ZK")
end
