local zk_api = require("zk.api")
local channel = require("plenary.async.control").channel
local lsp_util = require("vim.lsp.util")
local async = require("plenary.async")
local utils = require("journal.utils")

local M = {}

-- Check if LSP definition is available at the current cursor position
function M.is_lsp_definition_available(cb)
	cb = cb
		or function(unknown, to, from)
			if to then
				print("lsp available")
			else
				print("lsp not available")
			end
		end
	-- https://www.reddit.com/r/neovim/comments/r756ur/how_can_you_center_the_cursor_when_going_to/
	local params = lsp_util.make_position_params()
	vim.lsp.buf_request(0, "textDocument/definition", params, cb)
end

function M.jump_to_tag_definition_page()
	-- local await_schedule = async.util.scheduler
	local line, idx, len, csrow, off = utils.get_interested_item()

	local word = vim.fn.strcharpart(line, idx, len)
	local word_prefix = vim.fn.strcharpart(line, idx - 1, 1)

	-- oneshot
	local channel_tx, channel_rx = channel.oneshot()
	-- multiple producer, single consumer
	-- local channel_tx, channel_rx = channel.mpsc()

	-- learn how to use channels from plenary
	-- use nvim-telescope as reference
	async.run(function()
		-- oneshot
		local found = channel_rx()

		-- -- for i = 1, 3 do
		-- MPSC
		-- local found = channel_rx.recv()
		-- vim.print("got .." .. found.absPath)
		-- vim.print("source path.." .. source_path)
		-- -- vim.cmd("wincmd L") -- Move to the rightmost window
		-- if found.absPath ~= source_path then
		-- 	vim.print("Opening.." .. found.absPath)
		for _, path in ipairs(found) do
			vim.cmd("vsplit " .. path)
		end
		-- end
		-- -- end

		-- local timer = vim.loop.new_timer()
		-- timer:start(
		-- 	1000,
		-- 	0,
		-- 	vim.schedule_wrap(function()
		-- 		while true do
		-- 			local found = channel_rx.recv()
		-- 			vim.print("got .." .. found.absPath)
		-- 			vim.print("source path.." .. source_path)
		-- 			-- vim.cmd("wincmd L") -- Move to the rightmost window
		-- 			if found.absPath ~= source_path then
		-- 				vim.print("Opening.." .. found.absPath)
		-- 				vim.cmd("vsplit " .. found.absPath)
		-- 				-- end
		-- 			end
		-- 		end
		-- 	end)
		-- )
	end, function()
		print("finished")
	end)

	-- tag should always be created in the slugged form
	local norm_tag = utils.slugify_tag_word(word)

	-- local found = {}
	-- https://github.com/zk-org/zk/blob/main/docs/editors-integration.md#zklist
	if word_prefix == "#" then
		zk_api.list(os.getenv("ZK_NOTEBOOK_DIR"), {
			select = { "title", "path", "absPath", "metadata" },
			tags = { norm_tag },
			-- match = { norm_tag },
			matchStrategy = "exact",
		}, function(err, notes)
			vim.print("ZK LOOKING FOR: " .. norm_tag)
			local exists = false
			local _found = {}
			for _, note in ipairs(notes) do
				-- in order to open the notes, it must have the tag: zk and actually have the normalized tag in its taglist
				if
					-- only valid if the metadata is tagged with "zk: tag" or "zk: moc", and the tag list contains the normalized
					(vim.tbl_get(note, "metadata", "zk") == "tag" or vim.tbl_get(note, "metadata", "zk") == "moc")
					and vim.tbl_contains(note.metadata.tags or {}, norm_tag)
				then
					-- if note.title:find(norm_tag) then
					exists = true
					_found = utils.merge_unique(_found, { note.absPath })
					-- singleshot
					-- channel_tx(note)
					-- mpsc
					-- end
				end
			end

			if exists then
				channel_tx(_found)
			-- channel_tx.send(note)
			elseif
				not exists
				and vim.fn.input({
						prompt = "Create a new tag file '" .. word .. "'? [y]/n: ",
						default = "y",
					})
					== "y"
			then
				local _tags = utils.merge_unique({ norm_tag, word })
				zk_api.new(os.getenv("ZK_NOTEBOOK_DIR"), {
					-- insertLinkAtLocation = location,
					dir = vim.fn.expand("%:p:h"),
					group = "tag",
					title = word,
					extra = {
						tag = "[" .. table.concat(_tags, ", ") .. "]",
					},
				}, function(_err, note)
					if _err then
						vim.print(_err)
					else
						vim.cmd("e " .. note.path)
					end
				end)
			end
		end)
	end

	-- is_lsp_definition_available(function(unknown, to, from)
	--   if to then
	--     print("lsp available")
	--   else
	--     print("lsp not available")
	--     -- zk.new({
	--     --   insertLinkAtLocation = location,
	--     --   dir = vim.fn.expand("%:p:h"),
	--     --   group = "fleeting",
	--     --   title = word,
	--     -- })
	--     -- vim.print(location)
	--   end
	-- end)
end

return M
