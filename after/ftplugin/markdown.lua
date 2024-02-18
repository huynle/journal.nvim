-- If this file does loads with any error or "vim.notify" "press Enter to continue"
-- message, markdown syntax might not be correct

local utils = require("journal.utils")
local zk_helpers = require("autozk.helpers")

-- util.nnoremap("\\d", "<cmd>put =strftime(\"%Y-%m-%d\")<CR>")
local function link_surround()
	local line, idx, len, csrow, off = utils.get_interested_item()
	-- Stich selection with link into original line and replace it.
	local new = vim.fn.strcharpart(line, 0, idx)
		.. "["
		.. vim.fn.strcharpart(line, idx, len)
		.. "]()"
		.. vim.fn.strcharpart(line, idx + len)
	vim.fn.setline(csrow, new)
	vim.fn.setpos(".", { 0, csrow, idx + len + 4, off })
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
local okay, _util = pcall(require, "zk.util")
if not okay then
	utils.log("cannot load ZK plugin", vim.log.levels.WARN)
	return
end

local file_path = vim.fn.expand("%:p")

if _util.notebook_root(file_path) ~= nil then
	-- if require("zk.util").notebook_root(vim.fn.expand("%:p")) ~= nil then
	vim.keymap.set("n", "<C-CR>", function()
		zk_helpers.jump_to_tag_definition_page()
	end, opts)

	vim.keymap.set("v", "<C-CR>", function()
		zk_helpers.jump_to_tag_definition_page()
	end, opts)

	vim.keymap.set("n", "<leader>uz", function()
		toggle_auto_zk()
	end, opts)

	vim.keymap.set("n", "<leader>zz", function()
		vim.cmd("AutoZ")
	end, opts)
else
	utils.log("ZK notebook not detected for " .. file_path, vim.log.levels.DEBUG)
end
