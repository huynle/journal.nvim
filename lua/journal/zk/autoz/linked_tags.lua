local BaseAutoz = require("journal.zk.autoz.base")
local utils = require("journal.utils")
local classes = require("journal.common.classes")

local Taglinks = classes.class(BaseAutoz)

function Taglinks:init(opts)
	self.super:init(opts)
	self.name = "autoz-link-by-tags"
	self.zk_opts = {
		select = { "title", "metadata", "absPath" },
		linkedby = { vim.api.nvim_buf_get_name(0) },
	}
end

function Taglinks:lookup(notes, opts)
	local tags = utils.get_note_attr(notes, "tags")

	if not self.view then
		self.view = self:get_view()
	end
	-- get a new tree
	self.tree = self:get_tree()
	self:do_keymaps()
	for _, tag in ipairs(tags) do
		vim.schedule(function()
			utils.my_zk({
				tags = { tag },
			}, function(result)
				self:show_partial(result)
			end)
		end)
	end
end

return Taglinks
