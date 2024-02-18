local api = require("zk.api")
local config = require("journal.config")
local Path = require("plenary.path")

local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

local M = {}

function M.jump_to_item(win, precmd, item)
	-- requiring here, as otherwise we run into a circular dependency
	local View = require("journal.view")

	View.switch_to(win)
	if precmd then
		vim.cmd(precmd)
	end
	if vim.api.nvim_buf_get_option(item.bufnr, "buflisted") == false then
		vim.cmd("edit #" .. item.bufnr)
	else
		vim.cmd("buffer " .. item.bufnr)
	end
	vim.api.nvim_win_set_cursor(win, { item.start.line + 1, item.start.character })
end

---Finds the root directory of the notebook of the given path
--
---@param notebook_path string
---@return string? root
function M.notebook_root(notebook_path)
	return require("zk.root_pattern_util").root_pattern(".zk")(notebook_path)
end

---Try to resolve a notebook path by checking the following locations in that order
---1. current buffer path
---2. current working directory
---3. `$ZK_NOTEBOOK_DIR` environment variable
---
---Note that the path will not necessarily be the notebook root.
--
---@param bufnr number?
---@return string? path inside a notebook
function M.resolve_notebook_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local cwd = vim.fn.getcwd(0)
	-- if the buffer has no name (i.e. it is empty), set the current working directory as it's path
	if path == "" then
		path = cwd
	end
	if not M.notebook_root(path) then
		if not M.notebook_root(cwd) then
			-- if neither the buffer nor the cwd belong to a notebook, use $ZK_NOTEBOOK_DIR as fallback if available
			if vim.env.ZK_NOTEBOOK_DIR then
				path = vim.env.ZK_NOTEBOOK_DIR
			end
		else
			-- the buffer doesn't belong to a notebook, but the cwd does!
			path = cwd
		end
	end
	-- at this point, the buffer either belongs to a notebook, or everything else failed
	return path
end

---Makes an LSP location object from the last selection in the current buffer.
--
---@return table LSP location object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#location
function M.get_lsp_location_from_selection()
	local params = vim.lsp.util.make_given_range_params()
	params.uri = params.textDocument.uri
	params.textDocument = nil
	params.range = M.get_selected_range() -- workaround for neovim 0.6.1 bug (https://github.com/mickael-menu/zk-nvim/issues/19)
	return params
end

---Gets the text in the given range of the current buffer.
---Needed until https://github.com/neovim/neovim/pull/13896 is merged.
--
---@param range table contains {start} and {end} tables with {line} (0-indexed, end inclusive) and {character} (0-indexed, end exclusive) values
---@return string? text in range
function M.get_text_in_range(range)
	local A = range["start"]
	local B = range["end"]

	local lines = vim.api.nvim_buf_get_lines(0, A.line, B.line + 1, true)
	if vim.tbl_isempty(lines) then
		return nil
	end
	local MAX_STRING_SUB_INDEX = 2 ^ 31 - 1 -- LuaJIT only supports 32bit integers for `string.sub` (in block selection B.character is 2^31)
	lines[#lines] = string.sub(lines[#lines], 1, math.min(B.character, MAX_STRING_SUB_INDEX))
	lines[1] = string.sub(lines[1], math.min(A.character + 1, MAX_STRING_SUB_INDEX))
	return table.concat(lines, "\n")
end

---Gets the most recently selected range of the current buffer.
---That is the text between the '<,'> marks.
---Note that these marks are only updated *after* leaving the visual mode.
--
---@return table selected range, contains {start} and {end} tables with {line} (0-indexed, end inclusive) and {character} (0-indexed, end exclusive) values
function M.get_selected_range()
	-- code adjusted from `vim.lsp.util.make_given_range_params`
	-- we don't want to use character encoding offsets here

	local A = vim.api.nvim_buf_get_mark(0, "<")
	local B = vim.api.nvim_buf_get_mark(0, ">")

	-- convert to 0-index
	A[1] = A[1] - 1
	B[1] = B[1] - 1
	if vim.o.selection ~= "exclusive" then
		B[2] = B[2] + 1
	end
	return {
		start = { line = A[1], character = A[2] },
		["end"] = { line = B[1], character = B[2] },
	}
end

function M.warn(msg)
	vim.notify(msg, vim.log.levels.WARN, { title = "Trouble" })
end

function M.error(msg)
	vim.notify(msg, vim.log.levels.ERROR, { title = "Trouble" })
end

function M.debug(msg)
	if config.debug then
		vim.notify(msg, vim.log.levels.DEBUG, { title = "Trouble" })
	end
end

function M.throttle(ms, fn)
	local timer = vim.loop.new_timer()
	local running = false
	return function(...)
		if not running then
			local argv = { ... }
			local argc = select("#", ...)

			timer:start(ms, 0, function()
				running = false
				pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
			end)
			running = true
		end
	end
end

function M.splitStr(inputstr, opts)
	opts = vim.tbl_deep_extend("force", {
		sep = "%s",
		clean_before = true,
		clean_after = true,
	}, opts)
	-- return an ordered table, or key and its index
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. opts.sep .. "]+)") do
		str = M.cleanStr(str, opts)
		if str ~= "" then
			t[#t + 1] = str
		end
	end
	return t
end

function M.cleanStr(line, opts)
	opts = vim.tbl_deep_extend("force", {
		clean_before = false,
		clean_after = true,
	}, opts)

	if opts.clean_before then
		line = line:gsub("^%s+", "")
	end

	if opts.clean_after then
		line = line:gsub("%s+$", "")
	end
	-- strip ending spaces from line
	return line
end

function M.count(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

function M.is_array(t)
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then
			return false
		end
	end
	return true
end

function M.isempty(s)
	-- when a visual selection is empty, it produces \r\27
	return s == nil or s == "" or s == "\r\27" or s:match("^%s*$") ~= nil
end

function M.ternary(cond, T, F)
	if cond then
		return T
	else
		return F
	end
end

function M.get_visual_lines(bufnr)
	vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)
	vim.api.nvim_feedkeys("gv", "x", false)
	vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

	local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
	local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

	-- get whole buffer if there is no current/previous visual selection
	if start_row == 0 then
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		start_row = 1
		start_col = 0
		end_row = #lines
		end_col = #lines[#lines]
	end

	-- use 1-based indexing and handle selections made in visual line mode (see :help getpos)
	start_col = start_col + 1
	end_col = math.min(end_col, #lines[#lines] - 1) + 1

	-- shorten first/last line according to start_col/end_col
	lines[#lines] = lines[#lines]:sub(1, end_col)
	lines[1] = lines[1]:sub(start_col)

	return lines, start_row, start_col, end_row, end_col
end

function M.compareVerseKeys(a, b)
	local aBook, aChapter, aVerse = a:match("^(.-)%-(%d+)%-(%d+)$")
	local bBook, bChapter, bVerse = b:match("^(.-)%-(%d+)%-(%d+)$")
	aChapter = tonumber(aChapter)
	bChapter = tonumber(bChapter)
	aVerse = tonumber(aVerse)
	bVerse = tonumber(bVerse)

	if aBook ~= bBook then
		return aBook < bBook
	elseif aChapter ~= bChapter then
		return aChapter < bChapter
	else
		return aVerse < bVerse
	end
end

function M.sort_verse(myTable)
	local sortedKeys = {}
	for key, _ in pairs(myTable) do
		table.insert(sortedKeys, key)
	end

	table.sort(sortedKeys, M.compareVerseKeys) -- Sorts the keys alphabetically
	return sortedKeys
end

function M.split_and_join(val, opts)
	opts = opts or {}
	opts = vim.tbl_extend("force", {
		-- split by all spaces and commas
		split = "[%s%,]+",
		join = nil,
	}, opts)

	local _vals = vim.split(val, opts.split)
	local clean_vals = {}
	for _, val in ipairs(_vals) do
		table.insert(clean_vals, vim.fn.trim(val))
	end

	if opts.join then
		return table.concat(clean_vals, opts.join)
	end
	return clean_vals
end

function M.urlencode_value(value)
	if type(value) == "table" then
		local _value = {}
		for _, item in ipairs(value) do
			local _encoded = M._urlencode(item)
			table.insert(_value, _encoded)
		end
		return table.concat(_value, "%%20")
	else
		return string.gsub(value, " ", "%%20") -- Encode spaces as %20
	end
end

function M.urlencode(params)
	local encoded_params = {}
	for key, value in pairs(params) do
		key = M.urlencode_value(key) -- Encode spaces as %20
		value = M.urlencode_value(value) -- Encode spaces as %20
		table.insert(encoded_params, key .. "=" .. value)
	end
	return table.concat(encoded_params, "&")
end

function M.augroup(group_name, definition)
	vim.api.nvim_command("augroup " .. group_name)
	vim.api.nvim_command("autocmd!")
	for _, def in ipairs(definition) do
		local command = table.concat(vim.tbl_flatten({ "autocmd", def }), " ")
		vim.api.nvim_command(command)
	end
	vim.api.nvim_command("augroup END")
end

function M.augroups(definitions)
	for group_name, definition in pairs(definitions) do
		M.augroup(group_name, definition)
	end
end

function M.get_interested_item()
	local mode = vim.fn.mode()
	local bufnr, off, len, line, idx
	local csrow, cscol, cerow, cecol

	if mode == "n" then
		local cword = vim.fn.expand("<cword>")
		bufnr, csrow, cscol, off = unpack(vim.fn.getpos("."))
		len = vim.fn.strchars(cword)
		line = vim.fn.getline(csrow)
		idx = vim.fn.stridx(line, cword, 0)
	elseif mode == "v" or mode == "" then
		bufnr, csrow, cscol, off = unpack(vim.fn.getpos("."))
		_, cerow, cecol, _ = unpack(vim.fn.getpos("v"))
		if cecol < cscol then
			cscol, cecol = cecol, cscol
		end
		if csrow ~= cerow then
			vim.notify("Cannot link across lines", vim.log.levels.ERROR)
			return
		end
		idx = cscol - 1
		len = cecol - idx
		line = vim.fn.getline(csrow)
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "x", true)
	else
		vim.notify("Cannot link across lines", vim.log.levels.ERROR)
		return
	end

	return line, idx, len, csrow, off
end

function M.SplitThenJoin(val, opts)
	opts = opts or {}
	-- split by all spaces and commas
	local split = opts.split or "[%s%,]+"
	local join = opts.join or ", "
	return table.concat(vim.split(val, split), join)
end

function M.link_selection(entry)
	local type = "rel"
	local link = ""
	local current_path = vim.fn.expand("%:p:h")

	if type == "abs" then
		link = entry.path
	elseif type == "rel" then
		-- resolve any symlink that is goin on
		local r = Path:new(vim.fn.resolve(current_path))
		local p = Path:new(vim.fn.resolve(entry.path))
		link = p:make_relative(r .. r._sep)
	elseif type == "file" then
		link = trueFileName(entry.absPath)
	end

	-- Check if we can write on buffer
	if vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "modifiable") then
		local linkname = vim.fn.input("Link Name: ")
		if linkname == "" then
			linkname = entry.title
		end
		pasteMdLink(link, linkname)
	end
end

function M.pasteMdLink(link, name)
	vim.api.nvim_paste(" [" .. name .. "]" .. "(" .. link .. ")", true, -1)
end

function M.trueFileName(file)
	return file:match("[^/]*.$")
end

-- function M.log(msg, hl, name)
-- 	name = name or "Neovim"
-- 	hl = hl or "Todo"
-- 	local debug = vim.env.USER == "huy"
-- 	if debug then
-- 		vim.api.nvim_echo({ { name .. ": ", hl }, { msg } }, true, {})
-- 	end
-- end

local log_filename =
	Path:new(vim.fn.stdpath("state")):joinpath("journal", "journal-" .. os.date("%Y-%m-%d") .. ".log"):absolute() -- convert Path object to string

function M.write_to_log(msg)
	local file = io.open(log_filename, "ab")
	if file then
		file:write(os.date("[%Y-%m-%d %H:%M:%S] "))
		file:write(msg .. "\n")
		file:close()
	else
		vim.notify("Failed to open log file for writing", vim.log.levels.ERROR)
	end
end

function M.log(msg, level)
	level = level or vim.log.levels.INFO

	msg = vim.inspect(msg)
	if level >= config.options.debug.log_level then
		M.write_to_log(msg)
	end

	if level >= config.options.debug.notify_level then
		vim.notify(msg, level, { title = "Journal.nvim Debug" }, level)
	end
end

-- Function to merge two lists and keep unique elements
function M.merge_unique(list1, list2)
	local merged = {}

	-- Add elements from list1 to the merged list
	for _, value in ipairs(list1 or {}) do
		if not vim.tbl_contains(merged, value) then
			table.insert(merged, value)
		end
	end

	-- Add elements from list2 to the merged list (if not already present)
	for _, value in ipairs(list2 or {}) do
		if not vim.tbl_contains(merged, value) then
			table.insert(merged, value)
		end
	end

	return merged
end

function M.check_buffer(bufnr, check_str, substring)
	-- grab everything from first line to the last line
	-- Indexing is zero-based, end-exclusive. Negative indices are
	-- interpreted as length+1+index: -1 refers to the index past the
	-- end. So to get the last element use start=-2 and end=-1.
	local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for _, v in ipairs(content) do
		if substring then
			if string.find(v, check_str) then
				return true
			end
		else
			if v == check_str then
				return true
			end
		end
	end
	return false
end

function M.get_relative_path(buffername, directory)
	local current_directory = vim.fn.getcwd()
	local current_buffername = vim.fn.expand(buffername)
	-- Convert paths to absolute paths
	current_directory = vim.fn.resolve(current_directory)
	directory = vim.fn.resolve(directory)
	-- Get the relative path using the 'fnamemodify' function
	local relative_path = vim.fn.fnamemodify(current_buffername, ":~:.")
	relative_path = vim.fn.fnamemodify(relative_path, ":h")
	-- Append the relative path to the given directory
	local final_path = vim.fn.pathshorten(directory .. "/" .. relative_path)
	return final_path
end

-- Function to convert text to lowercase and remove hyphens
function M.slugify_tag_word(input_text)
	-- Convert to lowercase and remove hyphens
	local result_text = input_text:lower():gsub("-", "")
	-- result_text = result_text:lower():gsub(" ", "")
	return result_text
end

function M.my_zk(options, cb)
	local _defaults = {
		select = { "title", "tags", "absPath" },
	}
	options = options or {}
	options.select = M.merge_unique(_defaults.select, options.select or {})

	-- kick it off, and let it run inthe background
	vim.schedule(function()
		api.list(os.getenv("ZK_NOTEBOOK_DIR"), options, function(err, res)
			if not res then
				error(err)
			else
				cb(res, options)
			end
		end)
	end)
end

function M.get_note_attr(notes, attr)
	local ret = {}
	for _, note in ipairs(notes) do
		local _attr = note[attr]
		_attr = vim.tbl_islist(_attr) and _attr or { _attr }
		ret = M.merge_unique(ret, _attr)
	end
	return ret
end

function M.shallow_copy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

return M
