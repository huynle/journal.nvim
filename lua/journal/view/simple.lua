local classes = require("journal.common.classes")

local SimpleView = classes.class()

function SimpleView:init(visitor, opts)
	self.visitor = visitor
	-- Set default values for the options table if it's not provided.
	opts = vim.tbl_extend("force", {
		buf = {
			swapfile = false,
			bufhidden = "wipe",
			filetype = "zk_huy",
		},
		buf_vars = {
			test = "foo",
		},
		win = {
			wrap = true,
			cursorline = true,
		},
		keymaps = {},
	}, opts or {})
	self.opts = opts
	self.visible = false

	self.name = opts.buf.filetype
	self.bufnr = nil
end

-- Define a function that creates a new window with the given options.
-- The function returns the buffer and window handles.
-- function SimpleView:show(opts)
-- 	self.visible = true
-- 	opts = vim.tbl_extend("force", self.opts, opts or {})
--
-- 	-- Save the handle of the window from which we open the navigation.
-- 	local start_win = vim.api.nvim_get_current_win()
--
-- 	-- Get the buffer handle.
-- 	-- local buf = vim.fn.bufnr(self.name)
-- 	local buf = self.bufnr
--
-- 	-- Get the window handle.
-- 	local win
--
-- 	-- If the buffer already exists, find the window that displays it and return its handle.
-- 	if buf ~= -1 then
-- 		for _, win_id in ipairs(vim.api.nvim_list_wins()) do
-- 			local bufnr = vim.api.nvim_win_get_buf(win_id)
-- 			if bufnr == buf then
-- 				vim.api.nvim_set_current_win(win_id)
-- 				vim.api.nvim_set_current_win(start_win)
-- 				return buf, win_id
-- 			end
-- 		end
-- 	end
--
-- 	-- Reset the current window to the one from which we opened the navigation.
-- 	vim.api.nvim_set_current_win(start_win)
--
-- 	-- Return the buffer and window handles.
-- 	return buf, win
-- end

function SimpleView:mount(name)
	-- Save the handle of the window from which we open the navigation.
	local start_win = vim.api.nvim_get_current_win()

	-- Get the buffer handle.
	-- local buf = vim.fn.bufnr(name)
	local buf = vim.g[name]

	-- If the buffer already exists, find the window that displays it and return its handle.
	if not buf == nil or buf ~= -1 then
		for _, win_id in ipairs(vim.api.nvim_list_wins()) do
			local bufnr = vim.api.nvim_win_get_buf(win_id)
			if bufnr == buf then
				vim.api.nvim_set_current_win(win_id)
				vim.api.nvim_set_current_win(start_win)
				self.bufnr = buf
				self.winid = win_id
				return buf, win_id
			end
		end
	end

	-- Open a new vertical window at the far right.
	-- vim.api.nvim_command("botright " .. "vnew")
	vim.api.nvim_command("vnew equalalways")

	-- Get the buffer and window handles of the new window.
	self.bufnr = vim.api.nvim_get_current_buf()
	self.winid = vim.api.nvim_get_current_win()

	-- -- Set the buffer type to "nofile" to prevent it from being saved.
	-- vim.api.nvim_buf_set_option(self.bufnr, "buftype", "nofile")

	-- Disable swapfile for the buffer.
	vim.api.nvim_buf_set_option(self.bufnr, "swapfile", false)

	-- Set the buffer's hidden option to "wipe" to destroy it when it's hidden.
	vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "delete")

	-- Set the buffer's filetype to the filetype specified in the options table.
	vim.api.nvim_buf_set_option(self.bufnr, "filetype", name or self.name)

	-- -- Set the name of the buffer to the buffer name specified in the options table.
	-- vim.api.nvim_buf_set_name(self.bufnr, name or self.name)

	-- Set buffer variables as specified in the options table.
	for key, value in pairs(self.opts.buf_vars or {}) do
		vim.api.nvim_buf_set_var(self.bufnr, key, value)
	end

	-- Set the window options as specified in the options table.
	-- vim.api.nvim_win_set_option(win, "wrap", opts.win.wrap)
	-- vim.api.nvim_win_set_option(win, "cursorline", opts.win.cursorline)

	-- Set the keymaps for the window as specified in the options table.
	for keymap, command in pairs(self.opts.keymaps) do
		vim.keymap.set("n", keymap, command, { noremap = true, buffer = self.bufnr })
	end
	vim.api.nvim_set_current_win(start_win)
	vim.g[name] = self.bufnr
end

function SimpleView:map(mode, key, command)
	mode = vim.tbl_islist(mode) and mode or { mode }
	vim.keymap.set(mode, key, command, { buffer = self.bufnr })
end

return SimpleView
