vim.api.nvim_create_user_command("JournalOpen", function(params)
	local args = loadstring("return " .. params.args)()
	require("journal").open_journal_file(args)
end, { nargs = "?", force = true, complete = "lua" })
