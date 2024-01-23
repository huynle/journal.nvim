local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local classes = require("journal.common.classes")
local Split = require("journal.view.split")
local SimpleView = require("journal.view.simple")
local config = require("journal.config")
local utils = require("journal.utils")

local Autoz = classes.class()

function Autoz:init(opts)
	opts = vim.tbl_extend("force", config.options, opts or {})
	self.opts = opts
	self.name = "autoz"
	self.view = nil
	self.tree = nil
	self.node = nil
	self.notes = {}
end

local function get_node_id(node)
	return node.text
end

function Autoz:get_view(opts)
	-- local view = Split(self, self.opts)
	local view = SimpleView.new(self, opts)
	view:mount(self.name)
	-- view:mount()
	-- view:hide()
	return view
end

function Autoz:make_node(note)
	local _node = NuiTree.Node({
		text = note.title,
		params = note,
	})
	return _node
end

function Autoz:show_partial(notes)
	local current_node_id = get_node_id(self.node)
	for _, note in ipairs(notes) do
		local _node = self:make_node(note)

		if self.tree:get_node(get_node_id(_node)) then
			-- dont add the node if it is already in the tree
		elseif current_node_id == get_node_id(_node) then
			-- dont add the node if it is the root/current file
		else
			self.tree:add_node(_node)
		end
	end
	self.tree:render()
end

function Autoz:prepare_view_bufffer()
	if self.view == nil then
		self.view = self:get_view()
		vim.api.nvim_buf_set_option(self.view.bufnr, "readonly", false)
		vim.api.nvim_buf_set_option(self.view.bufnr, "modifiable", true)
		vim.api.nvim_buf_set_option(self.view.bufnr, "ft", self.name)
		vim.api.nvim_buf_set_lines(self.view.bufnr, 0, -1, true, {})
		self:do_keymaps()
	end
	-- get a new tree
	self.tree = self:get_tree()
end

function Autoz:show(notes)
	self:prepare_view_bufffer()
	self:show_partial(notes)
end

function Autoz:run(filepath, opts)
	self:get_note(filepath, opts)
end

function Autoz:do_keymaps()
	local keymaps = {
		{
			mode = { "n", "v" },
			keys = { "<CR>", "sv" },
			note = "open note in vertical split",
			callback = function()
				local _location = utils.get_lsp_location_from_selection()
				local node = self.tree:get_node()
				vim.cmd("wincmd L") -- Move to the rightmost window
				vim.cmd("vsplit " .. node.params.absPath)
			end,
		},
		{
			mode = { "n" },
			keys = { "sg" },
			note = "open note in horizontal split",
			callback = function()
				local node = self.tree:get_node()
				vim.cmd("wincmd L") -- Move to the rightmost window
				vim.cmd("split" .. node.params.absPath)
			end,
		},
		{
			mode = { "n" },
			keys = { "st" },
			note = "open note in tab",
			callback = function()
				local node = self.tree:get_node()
				vim.cmd("wincmd L") -- Move to the rightmost window
				vim.cmd("tabedit " .. node.params.absPath)
			end,
		},
	}

	for _, keymap in pairs(keymaps) do
		local _keys = vim.tbl_islist(keymap.keys) and keymap.keys or { keymap.keys }
		for _, key in ipairs(_keys) do
			self.view:map(keymap.mode, key, keymap.callback)
		end
	end
end

function Autoz:get_note(filepath, opts)
	filepath = vim.tbl_islist(filepath) and filepath or { filepath }

	utils.my_zk({
		hrefs = filepath,
	}, function(result)
		for _, note in ipairs(result) do
			self.node = self:make_node(note)
		end
		self:lookup(result, opts)
	end)
end

function Autoz:refresh(note)
	-- nothing here
end

function Autoz:show_links(links, opts)
	for _, item in ipairs(links or {}) do
		local entry = item.title
		if not utils.check_buffer(self.view.bufnr, entry, false) then
			vim.api.nvim_buf_set_lines(self.view.bufnr, -1, -1, true, { entry })
		end
	end
end

function Autoz:get_tree()
	return NuiTree({
		bufnr = self.view.bufnr,
		nodes = {},
		get_node_id = get_node_id,
		prepare_node = function(node)
			local line = NuiLine()
			line:append(string.rep(">", node:get_depth() - 1))
			if node:has_children() then
				line:append(node:is_expanded() and " " or " ")
			else
				line:append("  ")
			end
			line:append(node.text or "")
			return line
		end,
	})
end

function Autoz:create_tree(notes)
	notes = notes or {}
	local tree = self:get_tree()
	-- after you get the tree, you create it the tree trunk and canopy
	-- vim.api.nvim_buf_set_lines(self.bufnr, -2, -1, false, content)
	for _, note in ipairs(notes) do
		local _node = NuiTree.Node({
			text = note.title,
			params = note,
		})
		-- table.insert(node, _node)
		tree:add_node(_node)
	end
	return tree
end

return Autoz
