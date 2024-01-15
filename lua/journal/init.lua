local config = require("journal.config")
-- local utils = require("journal.utils")
local Entry = require("journal.entry")
local M = {}

M.setup = function(options)
	config.setup(options)
end

M.open_journal_file = function(opts)
	local lookup = Entry.new(opts)
	lookup:open(opts)
end

M.open_file = function(file_name)
	local lookup = Entry.new()
	lookup:open({ filename = file_name })
end

return M
