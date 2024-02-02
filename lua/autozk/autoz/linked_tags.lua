local BaseAutoz = require("autozk.autoz.base")
local utils = require("journal.utils")

local Taglinks = BaseAutoz:extend("Taglinks")

function Taglinks:init(opts)
	Taglinks.super.init(opts)
	self.name = "autoz-link-by-tags"
	self.zk_opts = {
		select = { "title", "metadata", "absPath" },
		linkedby = { vim.api.nvim_buf_get_name(0) },
	}
end

function Taglinks:lookup(notes, opts)
	local tags = utils.get_note_attr(notes, "tags")
	self:prepare_view_bufffer()

	for _, tag in ipairs(tags) do
		vim.schedule(function()
			utils.my_zk({
				tags = { utils.slugify_tag_word(tag) },
			}, function(result)
				self:show_partial(result)
			end)
		end)
	end
end

return Taglinks
