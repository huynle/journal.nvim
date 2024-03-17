local config = require("journal.config")
local Entry = require("journal.entry")
local utils = require("journal.utils")
local M = {}

M.setup = function(options)
	config.setup(options)
	require("autozk.builtins")
end

M.open_journal_file = function(opts)
	local lookup = Entry(opts)
	lookup:open(opts)
end

M.open_file = function(file_name)
	local lookup = Entry()
	lookup:open({ filepath = vim.fn.expand(file_name) })
end

M.add_time_entry = function(entry_format)
	local opts = vim.tbl_extend("force", config.options.journal, {
		entry_format = entry_format,
	} or {})

	local bufnr = vim.api.nvim_get_current_buf()
	utils.add_timed_entry(bufnr, opts)
end

return M
