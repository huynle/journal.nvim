local utils = require("journal.utils")
local M = {}

function M.show_links(links, opts)
	for _, item in ipairs(links or {}) do
		local entry = item.title
		if not utils.check_buffer(opts.bufnr, entry, false) then
			vim.api.nvim_buf_set_lines(opts.bufnr, -1, -1, true, { entry })
		end
	end
end

return M
