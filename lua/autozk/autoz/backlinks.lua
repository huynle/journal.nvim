local BaseAutoz = require("autozk.autoz.base")

local Backlinks = BaseAutoz:extend("Backlinks")

function Backlinks:init(opts)
	Backlinks.super.init(opts)
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
