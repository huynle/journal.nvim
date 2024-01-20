local BaseAutoz = require("journal.zk.autoz.base")
local utils = require("journal.utils")
local classes = require("journal.common.classes")

local Forwardlinks = classes.class(BaseAutoz)

function Forwardlinks:init(opts)
	self.super:init(opts)
	self.name = "autoz-forwardlinks"
	self.zk_opts = {
		select = { "title", "metadata", "absPath" },
		linkedby = { vim.api.nvim_buf_get_name(0) },
	}
end

function Forwardlinks:lookup(notes, opts)
	local abs_paths = utils.get_note_attr(notes, "absPath")

	utils.my_zk({
		linkedBy = abs_paths,
	}, function(result)
		self:show(result)
	end)
end

return Forwardlinks
