local class = require("journal.common.class")
local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Backlinks = class("Backlinks", BaseAutoz) -- subclassing

function Backlinks:initialize(opts)
	BaseAutoz.initialize(self, opts) -- invoking the superclass' initializer
	self.name = "autoz-backlinks"
	self.zk_opts = {
		select = { "title" },
	}
end

function Backlinks:lookup(notes, opts)
	local abs_paths = utils.get_note_attr(notes, "absPath")

	utils.my_zk({
		location = self.location,
		linkTo = abs_paths,
	}, function(result)
		self:show(result)
	end)
end

return Backlinks
