local Object = require("journal.common.object")
local config = require("journal.config")
local Simple = require("journal.view.simple")
local util = require("journal.utils")

local Lookup = Object("Lookup")

function Lookup:init(opts)
	self.name = "journal"
	self.opts = vim.tbl_extend("force", config.options, opts or {})
	-- self.view = Split(self, opts)
	self.view = Simple(self.name, {
		enter = true,
		-- keymaps = {
		-- 	["<c-up>"] = function()
		-- 		self:previous_entry()
		-- 	end,
		-- 	["<c-down>"] = function()
		-- 		self:next_entry()
		-- 	end,
		-- },
	})
end

function Lookup:load_file(opts)
	opts = vim.tbl_extend("force", self.opts.journal, opts or {})
	local filepath = opts.filepath
	filepath = type(filepath) == "function" and filepath() or filepath
	self.view:mount(filepath)
	-- -- allows us to load any arbitrary file, not just markdown
	-- vim.api.nvim_set_current_win(self.view.winid)
	-- vim.cmd("edit " .. filepath)
	-- local _bufnr = vim.api.nvim_get_current_buf()
	-- self.view.bufnr = _bufnr
	local _bufnr = self.view.bufnr

	if opts.add_entry then
		self:add_frontmatter()
		util.add_timed_entry(_bufnr, opts)
	end

	self:do_keymap()
	-- view_utils.set_buf_options(self.view, self.opts)
end

function Lookup:do_keymap()
	-- close
	local keys = config.options.keymaps.close
	if type(keys) ~= "table" then
		keys = { keys }
	end
	for _, key in ipairs(keys) do
		self.view:map("n", key, function()
			if self.opts.stop and type(self.opts.stop) == "function" then
				self.opts.stop()
			end
			self.view:unmount()
		end)
	end

	-- next journal entry
	self.view:map("n", config.options.keymaps.next_entry, function()
		self:next_entry()
	end)

	-- next previous entry
	self.view:map("n", config.options.keymaps.previous_entry, function()
		self:previous_entry()
	end)
end

function Lookup:close()
	vim.cmd("q")
end

function Lookup:open(journal_opts)
	self:load_file(journal_opts)

	util.augroups({
		journal_autosave = {
			-- { "CursorHold,CursorHoldI", "<buffer>", "update" }
			{ "WinLeave", "<buffer>", "update" },
		},
	})
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

function Lookup:add_frontmatter()
	local frontmatter_title_str = vim.api.nvim_eval("strftime('title: W%W-%Y')")
	local frontmatter_date_str = vim.api.nvim_eval("strftime('date: %m/%d/%Y')")

	local check_date = util.check_for_entry(self.view.bufnr, "date:", true)
	local check_title = util.check_for_entry(self.view.bufnr, "title:", true)

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

return Lookup
