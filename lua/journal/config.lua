local M = {}

M.namespace = vim.api.nvim_create_namespace("journal")

local defaults = {
	view = {
		enter = true,
		buf_options = {
			modifiable = true,
		},
		win_options = {
			wrap = true,
			linebreak = true,
			-- winblend = 10,
			-- winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
		},
	},

	split_window = {
		-- relative = {
		-- 	type = "win",
		-- 	winid = "42",
		-- },
		relative = "editor",
		position = "right",
		size = "35%",
		focusable = true,
	},
	popup_window = {
		position = 1,
		padding = { 1, 1, 1, 1 },
		size = {
			width = "50%",
			-- height = 10,
			height = "50%",
		},
		focusable = true,
		zindex = 50,
		relative = "cursor",
		border = {
			style = "rounded",
		},
	},

	journal = {
		filepath = function()
			local name = os.date("W%W-%Y")
			return string.format("%s/journal/%s.md", os.getenv("ZK_NOTEBOOK_DIR"), name)
		end,
		file_fmt = "%sW%02d-%d.md",
		-- date_fmt = "## %a %m/%d/%Y",
		entry_fmt = {
			"+ %H:%M ",
		},
		add_entry = false,
	},
	keymaps = {
		close = "<c-c>",
		previous_entry = "<c-up>",
		next_entry = "<c-down>",
	},
}

M.options = {}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
