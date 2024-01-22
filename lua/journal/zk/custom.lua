local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local action_utils = require("telescope.actions.utils")
local previewers = require("telescope.previewers")

local delimiter = "\x01"

local CustomQuickSearch = {}

function CustomQuickSearch.create_note_entry_maker(_)
	return function(note)
		local body = note.body or note.path
		return {
			value = note,
			path = note.absPath,
			display = body,
			ordinal = body,
		}
	end
end

function CustomQuickSearch.make_note_previewer()
	return previewers.new_buffer_previewer({
		define_preview = function(self, entry)
			conf.buffer_previewer_maker(
				entry.value.absPath,
				self.state.bufnr,
				{ bufname = entry.value.title or entry.value.path }
			)
		end,
	})
end

function CustomQuickSearch.show_telescope_note_picker(notes, options, cb)
	options = options or {}
	local telescope_options = vim.tbl_extend("force", { prompt_title = options.title }, options.telescope_options or {})

	local notes_by_line = {}
	for _, _note in ipairs(notes) do
		for ith, line in ipairs(vim.fn.split(_note.body)) do
			_note.body = line
			_note.linenum = ith
			table.insert(notes_by_line, _note)
		end
	end

	pickers
		.new(telescope_options, {
			finder = finders.new_table({
				results = notes,
				-- results = notes_by_line,
				entry_maker = CustomQuickSearch.create_note_entry_maker(options),
			}),
			sorter = conf.file_sorter(options),
			previewer = CustomQuickSearch.make_note_previewer(),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					if options.multi_select then
						local selection = {}
						action_utils.map_selections(prompt_bufnr, function(entry, _)
							table.insert(selection, entry.value)
						end)
						if vim.tbl_isempty(selection) then
							selection = { action_state.get_selected_entry().value }
						end
						actions.close(prompt_bufnr)
						cb(selection)
					else
						actions.close(prompt_bufnr)
						cb(action_state.get_selected_entry().value)
					end
				end)
				return true
			end,
		})
		:find()
end

function CustomQuickSearch.show_fzf_note_picker(notes, options, cb)
	-- pulled from zk-nvim plugin
	options = options or {}
	vim.fn._fzf_wrap_and_run({
		source = vim.tbl_map(function(v)
			local body = v.body or v.path
			return table.concat({ v.absPath, body }, delimiter)
		end, notes),
		options = vim.list_extend({
			"--delimiter=" .. delimiter,
			"--tiebreak=index",
			"--with-nth=2",
			"--exact",
			"--tabstop=4",
			[[--preview=command -v bat 1>/dev/null 2>&1 && bat -p --color always {1} || cat {1}]],
			"--preview-window=wrap",
			options.title and "--header=" .. options.title or nil,
			options.multi_select and "--multi" or nil,
		}, options.fzf_options or {}),
		sinklist = function(lines)
			local notes_by_path = {}
			for _, note in ipairs(notes) do
				notes_by_path[note.absPath] = note
			end
			local selected_notes = vim.tbl_map(function(line)
				local path = string.match(line, "([^" .. delimiter .. "]+)")
				return notes_by_path[path]
			end, lines)
			if options.multi_select then
				cb(selected_notes)
			else
				cb(selected_notes[1])
			end
		end,
	})
end

function CustomQuickSearch.show_tag_picker(tags, options, cb)
	options = options or {}
	vim.fn._fzf_wrap_and_run({
		source = vim.tbl_map(function(v)
			return table.concat({ string.format("\x1b[31m%-4d\x1b[0m", v.note_count), v.name }, delimiter)
		end, tags),
		options = vim.list_extend({
			"--delimiter=" .. delimiter,
			"--tiebreak=index",
			"--nth=2",
			"--exact",
			"--tabstop=4",
			"--ansi",
			options.title and "--header=" .. options.title or nil,
			options.multi_select and "--multi" or nil,
		}, options.fzf or {}),
		sinklist = function(lines)
			local tags_by_name = {}
			for _, tag in ipairs(tags) do
				tags_by_name[tag.name] = tag
			end
			local selected_tags = vim.tbl_map(function(line)
				local name = string.match(line, "%d+%s+" .. delimiter .. "(.+)")
				return tags_by_name[name]
			end, lines)
			if options.multi_select then
				cb(selected_tags)
			else
				cb(selected_tags[1])
			end
		end,
	})
end

return CustomQuickSearch
