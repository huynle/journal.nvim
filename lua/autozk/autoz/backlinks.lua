local BaseAutoz = require("autozk.autoz.base")
local classes = require("journal.common.classes")

local Backlinks = classes.class(BaseAutoz)

function Backlinks:init(opts)
	self.super:init(opts)
	self.name = "autoz-backlinks"
	self.zk_opts = {
		select = { "title" },
		linkTo = { vim.api.nvim_buf_get_name(0) },
	}
end

function Backlinks:lookup(notes, opts)
	self:show(notes)
end

return Backlinks
