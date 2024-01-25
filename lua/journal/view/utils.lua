local config = require("journal.config")
local M = {}

function M.set_buf_options(popup, opts)
	-- vim.api.nvim_buf_set_option(popup.bufnr, "filetype", "journal")
	vim.api.nvim_buf_set_var(popup.bufnr, "journal_nvim", true)
end

function M.do_keymap(popup, opts)
	-- close
	local keys = config.options.keymaps.close
	if type(keys) ~= "table" then
		keys = { keys }
	end
	for _, key in ipairs(keys) do
		popup:map("n", key, function()
			if opts.stop and type(opts.stop) == "function" then
				opts.stop()
			end
			popup:unmount()
		end)
	end

	-- next journal entry
	popup:map("n", config.options.keymaps.next_entry, function()
		popup.visitor:next_entry()
	end)

	-- next previous entry
	popup:map("n", config.options.keymaps.previous_entry, function()
		popup.visitor:previous_entry()
	end)
end
return M
