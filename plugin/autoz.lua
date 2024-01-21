vim.api.nvim_create_user_command("AutoZK", function(params)
	local links = require("journal.zk.links")
	local renderer = require("journal.zk.renderer")

	local args = loadstring("return " .. params.args)()
	-- require("journal.zk").run_auto_zk(args)

	local function run_auto_zk(opts)
		if vim.b["enable_auto_zk"] then
			links.get_backlinks(renderer.show_links)
			links.get_forwardlinks(renderer.show_links)
			-- links.get_mentions(renderer.show_links)
			links.get_backlinks_for_page_tags(renderer.show_links)
		end
	end
	run_auto_zk(args)
end, { nargs = "?", force = true, complete = "lua" })

vim.api.nvim_create_user_command("AutoZ", function(params)
	if vim.b["enable_auto_zk"] then
		local Backlinks = require("journal.zk.autoz.backlinks")
		local backlinks = Backlinks.new({})

		local Forwardlinks = require("journal.zk.autoz.forwardlinks")
		local forwardlinks = Forwardlinks.new({})

		local Taglinks = require("journal.zk.autoz.linked_tags")
		local taglinks = Taglinks.new({})

		backlinks:run(vim.api.nvim_buf_get_name(0))
		forwardlinks:run(vim.api.nvim_buf_get_name(0))
		taglinks:run(vim.api.nvim_buf_get_name(0))
	end
end, { nargs = "?", force = true, complete = "lua" })
