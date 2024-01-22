local zk = require("zk")
local zk_util = require("zk.util")
local commands = require("zk.commands")
local Path = require("plenary.path")
local util = require("journal.utils")
local custom = require("journal.zk.custom")

local function makeRelativePath(relative_to, current_path)
	local r = Path:new(vim.fn.resolve(current_path))
	local p = Path:new(vim.fn.resolve(relative_to))
	local link = p:make_relative(r .. r._sep)
	return link
end

local function make_edit_fn(defaults, picker_options)
	return function(options)
		options = vim.tbl_extend("force", defaults, options or {})
		zk.edit(options, picker_options)
	end
end

-- we want can't do vim.fn["fzf#wrap"] because the sink/sinklist funcrefs
-- are reset to vim.NIL when they are converted to Lua
vim.cmd([[
        function! _fzf_wrap_and_run(...)
          call fzf#run(call('fzf#wrap', a:000))
        endfunction
      ]])

commands.add("ZkInteractiveSearch", function(options)
	options = options or {}
	options = vim.tbl_extend("keep", options, {
		title = "Interactive Fuzzy Content Search",
		notebook_path = os.getenv("ZK_NOTEBOOK_DIR"),
		select = { "body", "path", "absPath" },
		picker_options = {
			multi_select = false,
		},
		fzf_options = {},
		telescope_options = {},
	})
	require("zk.api").list(options.notebook_path, options, function(err, notes)
		-- copied function from zk-nvim
		assert(not err, tostring(err))
		-- CustomQuickSearch.show_telescope_note_picker(notes, options, function(selected_notes)
		custom.show_fzf_note_picker(notes, options, function(selected_notes)
			-- do something with the notes
			if options.picker_options.multi_select == false then
				selected_notes = { selected_notes }
			end
			for _, note in ipairs(selected_notes) do
				vim.cmd("e " .. note.absPath)
			end
		end)
	end)
end)

commands.add("ZkOrphans", make_edit_fn({ orphan = true }, { title = "Zk Orphans" }))
commands.add("ZkRecents", make_edit_fn({ createdAfter = "2 weeks ago" }, { title = "Zk Recents" }))

commands.add("ZkFlimsyNotes", function(options)
	options = vim.tbl_extend("force", { orphan = true, sort = { "word-count" } }, options or {})
	zk.edit(options, { title = "Zk Flimsy Notes" })
end)

commands.add("ZkMentionedBy", function(options)
	options = vim.tbl_extend(
		"force",
		{ mentionedBy = { makeRelativePath(vim.fn.expand("%"), os.getenv("ZK_NOTEBOOK_DIR")) } },
		options or {}
	)
	zk.edit(options, { title = "Zk Mentioned By " .. vim.fn.expand("%:t") })
end)

commands.add("ZkMentioned", function(options)
	options = vim.tbl_extend("force", {
		mention = { makeRelativePath(vim.fn.expand("%"), os.getenv("ZK_NOTEBOOK_DIR")) },
	}, options or {})
	zk.edit(options, { title = "Zk Mentioned " .. vim.fn.expand("%:t") })
end)

-- Part of writing a great notebook is to establish links between related notes.
-- The --related <path> option can help by listing results having a linked note in common,
-- but not yet connected to the note.
commands.add("ZkRelated", function(options)
	options = vim.tbl_extend("force", {
		related = { makeRelativePath(vim.fn.expand("%"), os.getenv("ZK_NOTEBOOK_DIR")) },
		-- related = { vim.api.nvim_buf_get_name(0), },
	}, options or {})

	zk.edit(options, { title = "Zk Related" })
end)

-- commands.add("ZkFindAndLink", function(options)
--     local selected_text = vim.fn.VisualSelection()
--     local match = util.isempty(selected_text) and vim.fn.input("Find: ") or selected_text
--     options = vim.tbl_extend("force", { sort = { 'modified' }, match = match }, options or {})
--     zk.pick_notes(options, { title = "Zk Find and Link: " .. vim.inspect(match), multi_select = false },
--         link_selection)
-- end)

commands.add("ZkMultiTags", function(options)
	zk.pick_tags(options, { title = "Zk Multi Tags" }, function(tags)
		tags = vim.tbl_map(function(v)
			return v.name
		end, tags)
		zk.edit({ tags = tags }, { title = "Zk Notes for tag(s) " .. vim.inspect(tags) })
	end)
end)

commands.add("ZkMatchHuy", function(options)
	local selected_text = vim.fn.VisualSelection()
	local match = util.isempty(selected_text) and vim.fn.input("Match: ") or selected_text

	options = vim.tbl_extend("force", {
		sort = { "modified" },
		-- if personal laptop, user name. then use this method because of the updated `zk` binary
		-- match = vim.env.USER == "huy" and vim.split(match, "[%W]+") or match,
		match = vim.split(match, "[%W]+"),
		-- match = match,
	}, options or {})

	zk.edit(options, { title = "Zk Notes matching: " .. vim.inspect(match) })
end)

commands.add("ZkMatchTagsHuy", function(options)
	local selected_text = vim.fn.VisualSelection()
	local match = util.isempty(selected_text) and vim.fn.input("Find: ") or selected_text

	options = vim.tbl_extend("force", { tags = util.SplitThenJoin(selected_text, { split = "[%W]+" }) }, options or {})
	zk.edit(options, { title = "Zk Notes matching " .. vim.inspect(selected_text) })
end)

commands.add("ZkNewHuy", function(options)
	options = options or {}

	local directory = vim.fn.input("Dir: ")
	local input_title = vim.fn.input("title: ")
	zk.new(vim.tbl_extend("force", {
		dir = directory,
		title = input_title or "NONE",
		extra = {
			tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
		},
	}, options))
end)

commands.add("ZkNewHuyFromContentSelection", function(options)
	local input_title = vim.fn.input("Title: ")
	local directory = vim.fn.input("Dir: ")
	local location = util.get_lsp_location_from_selection()
	local selected_text = util.get_text_in_range(location.range)
	assert(selected_text ~= nil, "No selected text")

	input_title = not util.isempty(input_title) and input_title or selected_text

	zk.new(vim.tbl_extend("force", {
		dir = directory,
		title = input_title or "NONE",
		insertLinkAtLocation = location,
		content = selected_text,
		extra = {
			-- reference = vim.fn.input("Reference: "),
			tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
		},
	}, options or {}))
end, { needs_selection = true })

commands.add("ZkNewEntry", function(options)
	options = options or {}

	-- takes the split and clean it
	-- local input_tags = vim.split(vim.fn.input('Tags: '), '[%s%,]+')

	local input_reference = vim.fn.input("Reference: ")
	local input_title = vim.fn.input("Title: ")

	zk.new(vim.tbl_extend("force", {
		-- insertLinkAtLocation = location,
		dir = string.format("%s", os.getenv("ZK_NOTEBOOK_DIR")),
		-- dir = 'wiki',
		group = "fleeting",
		title = input_title or "NONE",
		extra = {
			reference = input_reference,
			tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
		},
	}, options))

	-- zk.new(vim.tbl_extend("force", {
	--   -- insertLinkAtLocation = location,
	--   dir = options.dir or string.format("%s", os.getenv("ZK_NOTEBOOK_DIR")),
	--   -- dir = 'wiki',
	--   group = options.group or "fleeting",
	--   title = input_title or "NONE",
	--   extra = {
	--     reference = input_reference,
	--     tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
	--   },
	-- }, options))
end)

commands.add("ZkNewWorkEntry", function(options)
	options = options or {}
	-- local location = zk_util.get_lsp_location_from_selection()
	-- local input_content = vim.fn.input("Content: ")
	-- TODO: need to parse multiple tags
	--
	-- local input_tags = vim.split(vim.fn.input('Tags: '), '[%s%,]+')
	-- local input_reference = vim.fn.input("Reference: ")

	local input_title = vim.fn.input("Title: ")
	zk.new(vim.tbl_extend("force", {
		-- insertLinkAtLocation = location,
		dir = options.dir or string.format("%s", os.getenv("ZK_WORK_NOTEBOOK_DIR")),
		-- dir = 'wiki',
		group = options.group or "fleeting",
		-- content = input_content,
		title = input_title or "NONE",
		extra = {
			reference = input_reference,
			tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
		},
	}, options or {}))
end)

commands.add("ZkNewFromContentSelectionHuy", function(options)
	-- options = dir=vim.fn.expand('%:p:h'), group='fleeting', title=vim.fn.input('Title: ')
	local location = util.get_lsp_location_from_selection()
	local selected_text = util.get_text_in_range(location.range)
	options.title = not util.isempty(options.title) and options.title or selected_text
	assert(selected_text ~= nil, "No selected text")
	zk.new(vim.tbl_extend("force", {
		insertLinkAtLocation = location,
		content = selected_text,
		extra = {
			-- reference = vim.fn.input("Reference: "),
			tag = "[" .. util.SplitThenJoin(vim.fn.input("Tags: ")) .. "]",
		},
	}, options or {}))
end, { needs_selection = true })

commands.add("ZkNewFromTitleSelectionHuy", function(options)
	local location = util.get_lsp_location_from_selection()
	local selected_text = util.get_text_in_range(location.range)
	assert(selected_text ~= nil, "No selected text")

	options = options or {}
	options.title = selected_text
	local group = vim.fn.input("ZK Type [fleeting]: ")
	options.group = group ~= "" and group or "fleeting"

	if options.inline == true then
		options.inline = nil
		options.dryRun = true
		options.insertContentAtLocation = location
	else
		options.insertLinkAtLocation = location
	end

	zk.new(options)
end, { needs_selection = true })
