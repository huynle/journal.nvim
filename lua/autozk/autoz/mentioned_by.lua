local class = require("journal.common.class")
local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Mentionedby = class("Backlinks", BaseAutoz) -- subclassing

function Mentionedby:initialize(opts)
	BaseAutoz.initialize(self, opts) -- invoking the superclass' initializer
	self.name = "autoz-mentionedby"
	self.zk_opts = {
		select = { "title" },
	}
end

function Mentionedby:lookup(notes, opts)
	local current_file = vim.api.nvim_buf_get_name(0)
	local relative_path = utils.makeRelativePath(current_file, self.location)

	utils.my_zk({
		location = self.location,
		mentionedBy = { relative_path },
	}, function(result)
		self:show(result)
	end)
end

return Mentionedby
