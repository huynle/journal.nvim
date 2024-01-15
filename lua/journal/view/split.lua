local Split = require("nui.split")
local config = require("journal.config")
local view_utils = require("journal.view.utils")

local SplitWindow = Split:extend("SplitWindow")

function SplitWindow:init(entry, options)
	options = vim.tbl_deep_extend("keep", options or {}, config.options.split_window)
	options = vim.tbl_deep_extend("keep", options or {}, config.options.view)
	self.opts = options
	self.entry = entry
	SplitWindow.super.init(self, options)
end

function SplitWindow:mount(filepath, opts)
	opts = opts or {}
	opts = vim.tbl_extend("force", self.opts, opts)

	SplitWindow.super.mount(self)
end

return SplitWindow
