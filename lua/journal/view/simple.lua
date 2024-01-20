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
function SimpleView:show(opts)
	self.visible = true
	opts = vim.tbl_extend("force", self.opts, opts or {})

	-- Save the handle of the window from which we open the navigation.
	local start_win = vim.api.nvim_get_current_win()

	-- Get the buffer handle.
	-- local buf = vim.fn.bufnr(self.name)
	local buf = self.bufnr

	-- Get the window handle.
	local win

	-- If the buffer already exists, find the window that displays it and return its handle.
	if buf ~= -1 then
		for _, win_id in ipairs(vim.api.nvim_list_wins()) do
			local bufnr = vim.api.nvim_win_get_buf(win_id)
			if bufnr == buf then
				vim.api.nvim_set_current_win(win_id)
				vim.api.nvim_set_current_win(start_win)
				return buf, win_id
			end
		end
	end

	-- Reset the current window to the one from which we opened the navigation.
	vim.api.nvim_set_current_win(start_win)

	-- Return the buffer and window handles.
	return buf, win
end

function SimpleView:mount(name)
	-- Open a new vertical window at the far right.
	vim.api.nvim_command("botright " .. "vnew")

	-- Get the buffer and window handles of the new window.
	self.bufnr = vim.api.nvim_get_current_buf()
	self.winid = vim.api.nvim_get_current_win()
	local buf = self.bufnr

	-- -- Set the name of the buffer to the buffer name specified in the options table.
	-- vim.api.nvim_buf_set_name(buf, name or self.name)

	-- Set the buffer type to "nofile" to prevent it from being saved.
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	-- Disable swapfile for the buffer.
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- Set the buffer's hidden option to "wipe" to destroy it when it's hidden.
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- Set the buffer's filetype to the filetype specified in the options table.
	vim.api.nvim_buf_set_option(buf, "filetype", name or self.name)

	-- Set buffer variables as specified in the options table.
	for key, value in pairs(self.opts.buf_vars or {}) do
		vim.api.nvim_buf_set_var(buf, key, value)
	end

	-- Set the window options as specified in the options table.
	-- vim.api.nvim_win_set_option(win, "wrap", opts.win.wrap)
	-- vim.api.nvim_win_set_option(win, "cursorline", opts.win.cursorline)

	-- Set the keymaps for the window as specified in the options table.
	for keymap, command in pairs(self.opts.keymaps) do
		vim.api.nvim_buf_set_keymap(buf, "n", keymap, command, { noremap = true })
	end
end

function SimpleView:map(mode, key, command)
	mode = vim.tbl_islist(mode) and mode or { mode }
	vim.keymap.set(mode, key, command, { buffer = self.bufnr })
end

return SimpleView
