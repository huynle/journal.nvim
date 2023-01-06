local util = require("hle.util")

local M = {}
M.options = {}
local buf, win, start_win

local defaults = {
	date_fmt = "## %a %m/%d/%Y",
	entry_fmt = "+ %H:%M ",
}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, defaults, M.options or {}, options or {})
end

function M.open()
	local path = vim.api.nvim_get_current_line()

	if vim.api.nvim_win_is_valid(start_win) then
		vim.api.nvim_set_current_win(start_win)
		vim.api.nvim_command("edit " .. path)
	else
		vim.api.nvim_command("leftabove vsplit " .. path)
		start_win = vim.api.nvim_get_current_win()
	end
end

-- After opening desired file user no longer need our navigation
-- so we should create function to closing it.
function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

function M.previous_entry()
	local journal = require("journal")
	local cur_path = vim.api.nvim_buf_get_name(0)

	local _, _, path, week, year = string.find(cur_path, "(.*)W(%d+)%-(%d+).md")
	local final_path = string.format("%sW%02d-%d.md", path, tonumber(week) - 1, year)

	M.close()
	journal:open_journal_file({
		filepath = final_path,
		add_entry = false,
	})
end

function M.next_entry()
	local journal = require("journal")

	local cur_path = vim.api.nvim_buf_get_name(0)
	local _, _, path, week, year = string.find(cur_path, "(.*)W(%d+)%-(%d+).md")
	local final_path = string.format("%sW%02d-%d.md", path, tonumber(week) + 1, year)
	M.close()
	journal:open_journal_file({
		filepath = final_path,
		add_entry = false,
	})
end

-- Ok. Now we are ready to making two first opening functions

function M.open_and_close()
	M.open() -- We open new file
	M.close() -- and close navigation
end

function M.preview()
	M.open() -- WE open new file
	-- but in preview instead of closing navigation
	-- we focus back to it
	vim.api.nvim_set_current_win(win)
end

-- To making splits we need only one function
function M.split(axis)
	local path = vim.api.nvim_get_current_line()

	-- We still need to handle two scenarios
	if vim.api.nvim_win_is_valid(start_win) then
		vim.api.nvim_set_current_win(start_win)
		-- We pass v in axis argument if we want vertical split
		-- or nothing/empty string otherwise.
		vim.api.nvim_command(axis .. "split " .. path)
	else
		-- if there is no starting window we make new on left
		vim.api.nvim_command("leftabove " .. axis .. "split " .. path)
		-- but in this case we do not need to set new starting window
		-- because splits always close navigation
	end

	M.close()
end

function M.open_in_tab()
	local path = vim.api.nvim_get_current_line()

	vim.api.nvim_command("tabnew " .. path)
	M.close()
end

function M.redraw_og()
	-- First we allow introduce new changes to buffer. We will block that at end.
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	local items_count = vim.api.nvim_win_get_height(win) - 1 -- get the window height
	local list = {}

	-- If you using nightly build you can get oldfiles like this
	local oldfiles = vim.v.oldfiles
	-- In stable version works only that
	local oldfiles = vim.api.nvim_get_vvar("oldfiles")

	-- Now we populate our list with X last items form oldfiles
	for i = #oldfiles, #oldfiles - items_count, -1 do
		-- We use build-in vim function fnamemodify to make path relative
		-- In nightly we can call vim function like that
		local path = vim.fn.fnamemodify(oldfiles[i], ":.")
		-- and this is stable version:
		local path = vim.api.nvim_call_function("fnamemodify", { oldfiles[i], ":." })

		-- We iterate form end to start, so we should insert items
		-- at the end of results list to preserve order
		table.insert(list, #list + 1, path)
	end

	-- We apply results to buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, list)
	-- And turn off editing
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.redraw(opts)
	-- opts = opts or {}
	-- opts = opts or {win=win, buf=buf}
	vim.api.nvim_win_set_buf(win, buf)
end

function M.set_mappings(opts)
	opts = opts or {}
	-- set mapping to the current buffer
	local mappings = {
		["<C-c>"] = "close()",
		["<C-up>"] = "previous_entry()",
		["<C-down>"] = "next_entry()",
		-- q = 'close()',
		-- ['<cr>'] = 'open_and_close()',
		-- v = 'split("v")',
		-- s = 'split("")',
		-- p = 'preview()',
		-- t = 'open_in_tab()'
	}

	for k, v in pairs(mappings) do
		-- vim.api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"journal.ui".' .. v .. '<cr>', {
		vim.api.nvim_buf_set_keymap(buf, "n", k, ':lua require"journal".' .. v .. "<cr>", {
			nowait = true,
			noremap = true,
			silent = true,
		})
	end
end

function M.create_ephem_win()
	-- We save handle to window from which we open the navigation
	start_win = vim.api.nvim_get_current_win()

	-- vim.api.nvim_command('botright 85vnew '..filepath) -- We open a new vertical window at the far right
	vim.api.nvim_command("botright 85vnew ") -- We open a new vertical window at the far right
	win = vim.api.nvim_get_current_win() -- We save our navigation window handle...
	buf = vim.api.nvim_get_current_buf() -- ...and it's buffer handle.

	-- We should name our buffer. All buffers in vim must have unique names.
	-- The easiest solution will be adding buffer handle to it
	-- because it is already unique and it's just a number.
	vim.api.nvim_buf_set_name(buf, "ephem #" .. buf)

	-- Now we set some options for our buffer.
	-- nofile prevent mark buffer as modified so we never get warnings about not saved changes.
	-- Also some plugins treat nofile buffers different.
	-- For example coc.nvim don't triggers aoutcompletation for these.
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	-- We do not need swapfile for this buffer.
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- And we would rather prefer that this buffer will be destroyed when hide.
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- It's not necessary but it is good practice to set custom filetype.
	-- This allows users to create their own autocommand or colorschemes on filetype.
	-- and prevent collisions with other plugins.
	-- vim.api.nvim_buf_set_option(buf, 'filetype', 'journalft')

	-- For better UX we will turn off line wrap and turn on current line highlight.
	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "cursorline", true)

	M.set_mappings(opts) -- At end we will set mappings for our navigation.
end

function M.create_win(filepath, opts)
	opts = opts or {}
	-- We save handle to window from which we open the navigation
	start_win = vim.api.nvim_get_current_win()

	vim.api.nvim_command("botright 85vnew " .. filepath) -- We open a new vertical window at the far right
	win = vim.api.nvim_get_current_win() -- We save our navigation window handle...
	buf = vim.api.nvim_get_current_buf() -- ...and it's buffer handle.

	-- We should name our buffer. All buffers in vim must have unique names.
	-- The easiest solution will be adding buffer handle to it
	-- because it is already unique and it's just a number.
	-- vim.api.nvim_buf_set_name(buf, 'journal #' .. buf)

	-- Now we set some options for our buffer.
	-- nofile prevent mark buffer as modified so we never get warnings about not saved changes.
	-- Also some plugins treat nofile buffers different.
	-- For example coc.nvim don't triggers aoutcompletation for these.
	-- vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')

	-- We do not need swapfile for this buffer.
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- And we would rather prefer that this buffer will be destroyed when hide.
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- It's not necessary but it is good practice to set custom filetype.
	-- This allows users to create their own autocommand or colorschemes on filetype.
	-- and prevent collisions with other plugins.
	-- vim.api.nvim_buf_set_option(buf, 'filetype', 'journalft')

	-- For better UX we will turn off line wrap and turn on current line highlight.
	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "cursorline", true)

	M.set_mappings() -- At end we will set mappings for our navigation.
end

function M.entry(filepath)
	local file = type(filepath) == "function" and filepath() or filepath

	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		M.create_win(file)
	end
	-- M.redraw()
	return buf, win
end

function M.ephemeral_entry(draw_fn, opts)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		M.create_ephem_win()
	end
	draw_fn(opts)
end

-- return {
--   entry = entry,
--   ephemeral_entry = ephemeral_entry,
--   close = close,
--   previous_entry = previous_entry,
--   next_entry = next_entry,
--   open_and_close = open_and_close,
--   preview = preview,
--   open_in_tab = open_in_tab,
--   split = split,
-- }
-- return M

-- NOTE: use this as base
-- - https://github.com/jakewvincent/mkdnflow.nvim
-- - https://github.com/renerocksai/telekasten.nvim/tree/main/lua
-- WRITE YOUR OWN PLUGGING:A
-- - https://www.2n.pl/blog/how-to-write-neovim-plugins-in-lua
-- - https://www.2n.pl/blog/how-to-make-ui-for-neovim-plugins-in-lua
-- - explore this dotfile. looks like he's all in all vimscript - https://github.com/joeytwiddle/dotfiles/tree/master/.vim
-- some good notes here that breaks down the little things about the language
-- https://wincent.com/wiki/Lua_development_in_Neovim
local configs = {
	filepath = function()
		local name = os.date("W%W-%Y")
		return string.format("%s/journal/%s.md", util.getEnv("ZK_NOTEBOOK_DIR"), name)
	end,
	add_entry = false,
}

-- local M = {}

function M:get_file_og(opts)
	opts = vim.tbl_extend("force", configs, opts or {})

	local filepath
	local file_dir

	-- if vim.env.JOURNAL_DIR then
	-- file_dir = vim.fn.GetEnv(vim.env.JOURNAL_DIR)
	if util.getEnv("JOURNAL_DIR") then
		file_dir = util.getEnv("JOURNAL_DIR")
	-- Print("GOT HERE 0 " .. file_dir)
	else
		-- Print("GOT HERE 1 " .. util.getEnv("JOURNAL_DIR"))
		-- file_dir = string.format('%s/journal/', util.getEnv(vim.env.ZK_NOTEBOOK_DIR))
		file_dir = string.format("%s/journal", util.getEnv("ZK_NOTEBOOK_DIR"))
	end

	-- if vim.env.JOURNAL_FILE then
	if util.getEnv("JOURNAL_FILE") then
		-- Print("GOT HERE 3 " .. util.getEnv("JOURNAL_DIR"))
		-- filepath = util.getEnv(vim.env.JOURNAL_FILE)
		filepath = util.getEnv("JOURNAL_FILE")
	else
		-- Print("GOT HERE 4 " .. file_dir)
		filepath = string.format("%s/%s.md", file_dir, opts.filename)
	end

	Print("GOT HERE 5 " .. filepath)
	return filepath
end

function M:get_private_file()
	local filepath
	local file_dir

	-- if vim.env.JOURNAL_DIR then
	-- file_dir = vim.fn.GetEnv(vim.env.JOURNAL_DIR)
	if util.getEnv("PRIVATE_JOURNAL_DIR") then
		file_dir = util.getEnv("PRIVATE_JOURNAL_DIR")
	else
		-- file_dir = string.format('%s/journal/', util.getEnv(vim.env.ZK_NOTEBOOK_DIR))
		file_dir = string.format("%s/thoughts/journal", util.getEnv("ZK_NOTEBOOK_DIR"))
	end

	if util.getEnv("PRIVATE_JOURNAL_FILE") then
		filepath = util.getEnv("PRIVATE_JOURNAL_FILE")
	else
		filepath = string.format("%s/%s.md", file_dir, os.date("W%W-%Y"))
	end

	return filepath
end

function M:hello()
	-- example how to write
	local pos = vim.api.nvim_win_get_cursor(0)[2]
	local line = vim.api.nvim_get_current_line()
	local nline = line:sub(0, pos) .. "hello" .. line:sub(pos + 1)
	vim.api.nvim_set_current_line(nline)
end

function M:add_timed_entry(buf, win)
	M:add_frontmatter(buf)

	local date_str = vim.fn.strftime(M.options.date_fmt)
	local time_str = vim.fn.strftime(M.options.entry_fmt)
	has_date = M:check(date_str, buf, false)

	-- now add the text that we need to at the END of the file
	if not has_date then
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", date_str, time_str })
	else
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { time_str })
	end
	-- get the total new line counts
	line_count = vim.api.nvim_buf_line_count(buf)
	-- set the cursor in the window
	vim.api.nvim_win_set_cursor(win, { line_count, 0 })
	vim.cmd("normal A")
end

function M:add_frontmatter(buf)
	local frontmatter_title_str = vim.api.nvim_eval("strftime('title: W%W-%Y')")
	local frontmatter_date_str = vim.api.nvim_eval("strftime('date: %m/%d/%Y')")

	local check_date = M:check("date:", buf, true)
	local check_title = M:check("title:", buf, true)

	if not check_title then
		vim.api.nvim_buf_set_lines(
			buf,
			0,
			0,
			false,
			{ "---", frontmatter_title_str, frontmatter_date_str, "lastmod: ", "---" }
		)
	end
end

function M:open_journal_file(opts)
	opts = vim.tbl_extend("force", configs, opts or {})

	local buf, win = M.entry(opts.filepath)

	if opts.add_entry then
		M:add_timed_entry(buf, win)
	end

	util.augroups({
		journal_autosave = {
			-- { "CursorHold,CursorHoldI", "<buffer>", "update" }
			{ "WinLeave", "<buffer>", "update" },
		},
	})
end

function M:open_file(filename)
	if type(filename) == "function" then
		filename = filename()
	end

	local ok, err = util.exists(vim.fn.expand(filename))

	if not ok then
		local value = vim.fn.input("Create New " .. vim.fn.expand(filename) .. "? y/[n]")
		if value == "" then
			return
		end
	end

	local buf, win
	buf, win = M.entry(vim.fn.expand(filename))
	M:add_timed_entry(buf, win)
	util.augroups({
		journal_autosave = {
			{ "CursorHold,CursorHoldI", "<buffer>", "update" },
		},
	})
end

function M:check(check_str, buf, substring)
	-- grab everything from first line to the last line
	-- Indexing is zero-based, end-exclusive. Negative indices are
	-- interpreted as length+1+index: -1 refers to the index past the
	-- end. So to get the last element use start=-2 and end=-1.
	local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for _, v in ipairs(content) do
		if substring then
			if string.find(v, check_str) then
				return true
			end
		else
			if v == check_str then
				return true
			end
		end
	end
	return false
end

return M
