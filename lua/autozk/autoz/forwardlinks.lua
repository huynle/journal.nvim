local class = require("journal.common.class")
local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Forwardlinks = class("Forwardlinks", BaseAutoz) -- subclassing

function Forwardlinks:initialize(opts)
	BaseAutoz.initialize(self, opts) -- invoking the superclass' initializer
	self.name = "autoz-forwardlinks"
	self.zk_opts = {
		select = { "title", "metadata", "absPath" },
	}
end

function Forwardlinks:lookup(notes, opts)
	local abs_paths = utils.get_note_attr(notes, "absPath")

	utils.my_zk({
		location = self.location,
		linkedBy = abs_paths,
	}, function(result)
		self:show(result)
	end)
end

return Forwardlinks
