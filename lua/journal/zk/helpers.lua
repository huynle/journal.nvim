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
	local params = vim.lsp.util.make_given_range_params()

	local word = vim.fn.strcharpart(line, idx, len)
	local word_prefix = vim.fn.strcharpart(line, idx - 1, 1)

	local tx, rx = channel.oneshot()

	-- learn how to use channels from plenary
	-- use nvim-telescope as reference
	async.run(function()
		local found = rx()
		vim.cmd("e " .. found.absPath)
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
			for _, note in ipairs(notes) do
				if note.metadata and note.metadata.zk and note.metadata.zk == "tag" then
					if note.title:find(norm_tag) then
						exists = true
						tx(note)
					end
				end
			end
			if
				not exists
				and vim.fn.input({
						prompt = "Create a new tag file '" .. norm_tag .. "'? [y]/n: ",
						default = "y",
					})
					== "y"
			then
				local _tags = utils.merge_unique({ norm_tag, word })
				zk_api.new(os.getenv("ZK_NOTEBOOK_DIR"), {
					-- insertLinkAtLocation = location,
					dir = vim.fn.expand("%:p:h"),
					group = "tag",
					title = norm_tag,
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
