local utils = require("journal.utils")
local M = {}

-- Define a function that creates a new window with the given options.
-- The function returns the buffer and window handles.
function M.create_win(opts)
	-- Set default values for the options table if it's not provided.
	local _defaults = {
		bufnr = nil,
		winid = nil,
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
	}

	opts = vim.tbl_extend("force", _defaults, opts or {})

	-- Save the handle of the window from which we open the navigation.
	local start_win = vim.api.nvim_get_current_win()

	-- Get the buffer name from the filetype specified in the options table.
	local buf_name = opts.buf.filetype

	-- Get the buffer handle.
	local buf = vim.fn.bufnr(buf_name)

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

	-- Open a new vertical window at the far right.
	vim.api.nvim_command("botright " .. "vnew")

	-- Get the buffer and window handles of the new window.
	buf = vim.api.nvim_get_current_buf()
	win = vim.api.nvim_get_current_win()

	-- Set the name of the buffer to the buffer name specified in the options table.
	vim.api.nvim_buf_set_name(buf, buf_name)

	-- Set the buffer type to "nofile" to prevent it from being saved.
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	-- Disable swapfile for the buffer.
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- Set the buffer's hidden option to "wipe" to destroy it when it's hidden.
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- Set the buffer's filetype to the filetype specified in the options table.
	vim.api.nvim_buf_set_option(buf, "filetype", opts.buf.filetype)

	-- Set buffer variables as specified in the options table.
	for key, value in pairs(opts.buf_vars) do
		vim.api.nvim_buf_set_var(buf, key, value)
	end

	-- Set the window options as specified in the options table.
	-- vim.api.nvim_win_set_option(win, "wrap", opts.win.wrap)
	-- vim.api.nvim_win_set_option(win, "cursorline", opts.win.cursorline)

	-- Set the keymaps for the window as specified in the options table.
	for keymap, command in pairs(opts.keymaps) do
		vim.api.nvim_buf_set_keymap(buf, "n", keymap, command, { noremap = true })
	end

	-- Reset the current window to the one from which we opened the navigation.
	vim.api.nvim_set_current_win(start_win)

	-- Return the buffer and window handles.
	return buf, win
end

function M.get_backlinks(cb, opts)
	local _defaults = {
		linkTo = { vim.api.nvim_buf_get_name(0) },
		buf = {
			filetype = "zk_backlinks",
		},
	}
	opts = vim.tbl_extend("force", _defaults, opts or {})
	local bufnr, win = M.create_win(opts)
	opts.bufnr = bufnr
	opts.winid = win
	vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, true, {})

	utils.my_zk(opts, cb)
end

function M.get_forwardlinks(cb, opts)
	local _defaults = {
		linkedBy = { vim.api.nvim_buf_get_name(0) },
		buf = {
			filetype = "zk_forwardlinks",
		},
	}
	opts = vim.tbl_extend("force", _defaults, opts or {})
	local bufnr, win = M.create_win(opts)
	opts.bufnr = bufnr
	opts.winid = win
	vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, true, {})

	utils.my_zk(opts, cb)
end

function M.get_mentions(cb, opts)
	local _defaults = {
		-- mentionedBy = { get_relative_path("%", os.getenv("ZK_NOTEBOOK_DIR")) },
		buf = {
			filetype = "zk_mentions",
		},
	}
	opts = vim.tbl_extend("force", _defaults, opts or {})
	local bufnr, win = M.create_win(opts)
	opts.bufnr = bufnr
	opts.winid = win
	vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, true, {})

	utils.my_zk(opts, cb)
end

function M.get_backlinks_for_page_tags(cb, opts)
	local _defaults = {
		hrefs = { vim.api.nvim_buf_get_name(0) },
		tags = {},
		buf = {
			filetype = "zk_tags",
		},
	}
	opts = vim.tbl_extend("force", _defaults, opts or {})
	local bufnr, win = M.create_win(opts)
	opts.bufnr = bufnr
	opts.winid = win
	vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, true, {})

	utils.my_zk({
		hrefs = opts.hrefs,
	}, function(result)
		opts.hrefs = nil
		for _, item in ipairs(result) do
			-- opts.tags = merge_unique(item.tags, opts.tags)
			for _, tag in ipairs(item.tags or {}) do
				opts.tags = { tag }
				utils.my_zk(opts, cb)
			end
		end
		-- if vim.tbl_isempty(opts.tags) then
		--   return cb({}, opts)
		-- end
		-- opts.hrefs = nil
		-- my_zk(opts, cb)
	end)
end

return M
