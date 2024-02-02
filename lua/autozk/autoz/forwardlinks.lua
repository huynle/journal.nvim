local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Forwardlinks = BaseAutoz:extend("Forwardlinks")

function Forwardlinks:init(opts)
	Forwardlinks.super.init(opts)
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
