local class = require("journal.common.class")
local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Mention = class("Backlinks", BaseAutoz) -- subclassing

function Mention:initialize(opts)
	BaseAutoz.initialize(self, opts) -- invoking the superclass' initializer
	self.name = "autoz-mention"
	self.zk_opts = {
		select = { "title" },
	}
end

function Mention:lookup(notes, opts)
	local current_file = vim.api.nvim_buf_get_name(0)
	local relative_path = utils.makeRelativePath(current_file, self.location)

	utils.my_zk({
		location = self.location,
		mention = { relative_path },
	}, function(result)
		for idx = #result, 1, -1 do
			if result[idx].absPath == current_file then
				table.remove(result, idx)
			end
		end

		self:show(result)
	end)
end

return Mention
