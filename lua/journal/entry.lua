local classes = require("journal.common.classes")
local config = require("journal.config")
local Split = require("journal.view.split")
local view_utils = require("journal.view.utils")

local Lookup = classes.class()

function Lookup:init(opts)
	self.opts = vim.tbl_extend("force", config.options, opts or {})
	self.view = Split(self, opts)
end

function Lookup:load_file(opts)
	local filepath = opts.filepath
	filepath = type(filepath) == "function" and filepath() or filepath

	-- allows us to load any arbitrary file, not just markdown
	vim.cmd("edit " .. filepath)
	local _bufnr = vim.api.nvim_get_current_buf()
	self.view.bufnr = _bufnr

	if opts.add_entry then
		self:add_timed_entry(_bufnr, opts)
	end

	view_utils.do_keymap(self.view, self.opts)
	view_utils.set_buf_options(self.view, self.opts)
end

function Lookup:close()
	vim.cmd("q")
end

function Lookup:open(journal_opts)
	journal_opts = vim.tbl_extend("force", self.opts.journal, journal_opts)
	-- self:load_file({ filepath = journal_opts.filepath })
	self.view:mount()
	self:load_file(journal_opts)

	-- util.augroups({
	-- 	journal_autosave = {
	-- 		-- { "CursorHold,CursorHoldI", "<buffer>", "update" }
	-- 		{ "WinLeave", "<buffer>", "update" },
	-- 	},
	-- })
end

function Lookup:get_bufnr()
	if not self._bufnr then
		self._bufnr = vim.api.nvim_get_current_buf()
	end
	return self._bufnr
end

function Lookup:next_entry()
	local cur_path = vim.api.nvim_buf_get_name(0)
	local _, _, path, week, year = string.find(cur_path, "(.*)W(%d+)%-(%d+).md")
	local final_path = string.format(config.options.journal.file_fmt, path, tonumber(week) + 1, year)
	-- local entry = Lookup.new(self.opts)
	-- self:close()
	self:load_file({
		filepath = final_path,
		add_entry = false,
	})
end

function Lookup:previous_entry()
	local cur_path = vim.api.nvim_buf_get_name(0)
	local _, _, path, week, year = string.find(cur_path, "(.*)W(%d+)%-(%d+).md")
	local final_path = string.format(config.options.journal.file_fmt, path, tonumber(week) - 1, year)
	-- local entry = Lookup.new(self.opts)
	-- self:close()
	self:load_file({
		filepath = final_path,
		add_entry = false,
	})
end

function Lookup:add_timed_entry(bufnr, journal_opts)
	-- journal_opts = vim.tbl_extend("force",Lookup:options, journal_opts)
	self:add_frontmatter()

	local entries = journal_opts.entry_fmt or { "" }

	for _, entry in ipairs(entries) do
		local fmt_entry = vim.fn.strftime(entry)
		if not self:check(bufnr, fmt_entry, false) then
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { fmt_entry })
			-- else
			-- 	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { entry })
		end
	end
	-- get the total new line counts
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	-- set the cursor in the window
	vim.api.nvim_win_set_cursor(self.view.winid, { line_count, 0 })
	vim.cmd("normal A")
end

function Lookup:add_frontmatter()
	local frontmatter_title_str = vim.api.nvim_eval("strftime('title: W%W-%Y')")
	local frontmatter_date_str = vim.api.nvim_eval("strftime('date: %m/%d/%Y')")

	local check_date = self:check(self.view.bufnr, "date:", true)
	local check_title = self:check(self.view.bufnr, "title:", true)

	if not check_title then
		vim.api.nvim_buf_set_lines(
			self.view.bufnr,
			0,
			0,
			false,
			{ "---", frontmatter_title_str, frontmatter_date_str, "lastmod: ", "---" }
		)
	end
end

-- function Lookup:open_file(filename)
-- 	if type(filename) == "function" then
-- 		filename = filename()
-- 	end
--
-- 	local ok, err = util.exists(vim.fn.expand(filename))
--
-- 	if not ok then
-- 		local value = vim.fn.input("Create New " .. vim.fn.expand(filename) .. "? y/[n]")
-- 		if value == "" then
-- 			return
-- 		end
-- 	end
--
-- 	local buf, win
-- 	buf, win = Lookup:entry(vim.fn.expand(filename))
-- 	Lookup:add_timed_entry(buf, win)
-- 	util.augroups({
-- 		journal_autosave = {
-- 			{ "CursorHold,CursorHoldI", "<buffer>", "update" },
-- 		},
-- 	})
-- end

function Lookup:check(bufnr, check_str, substring)
	-- grab everything from first line to the last line
	-- Indexing is zero-based, end-exclusive. Negative indices are
	-- interpreted as length+1+index: -1 refers to the index past the
	-- end. So to get the last element use start=-2 and end=-1.
	local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
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

return Lookup
