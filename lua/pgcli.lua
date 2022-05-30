local PGCLI = {
	config = {
		-- postgresql database name
		-- dev environment is assumed for this plugin
		-- thus no user name, password is provided here to make it simple
		database_name = "",
		host = "localhost",

		-- shortcut to execute query under the cursor line
		execute_line = "<leader>e",
		-- shortcut to execute query in selected text
		execute_selection = "<leader>e",
		-- shortcut to execute query in current paragraph
		execute_paragraph = "<leader>r",

		-- shortcut to close latest result bufer
		close_latest_result = "<leader>w",
		-- shortcut to close all result buffers
		close_all_results = "<leader>W",
	},
}

local query_resultplugin_buffers = {}

local function run_query(query)
	-- strip leading and trailing spaces
	query = string.gsub(query, "^%s*(.-)%s*$", "%1")

	if query == nil or query == "" then
		print("PGCLI plugin: query is empty")
		return
	end

	-- open horizontally split new window
	vim.cmd("split")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_win_set_buf(win, buf)

	-- remember new buffer for later to be able to close it
	table.insert(query_result_buffers, buf)

	-- show "Running ..." text until query is finished executing
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, { "# Running...", query, "" })
	vim.cmd("redraw")

	-- save query to a temp file
	local tmp_file = os.tmpname()
	local f = io.open(tmp_file, "w+")
	io.output(f)
	io.write("\\set QUIET 1 \n") -- no console output for the following commands
	io.write("\\timing on \n") -- show timing of queries
	io.write("\\pset null (NULL) \n") -- show nulls as "(NULL)"
	io.write("\\pset linestyle unicode \n") -- use prettier lines inside the table
	io.write("\\pset border 2 \n") -- show pretty lines outside the table

	io.write(query)
	io.close(f)

	-- execute query
	local result = vim.fn.systemlist(
		"pgcli "
			.. "-h "
			.. PGCLI.config.host
			.. "-p "
			.. PGCLI.config.port
			.. "-U "
			.. PGCLI.config.username
			.. "-f "
			.. tmp_file
	)

	os.remove(tmp_file)

	-- replace result buffer with query results
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, { query, "" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, true, result)
end

function PGCLI.query_current_line()
	local line_number = vim.api.nvim_win_get_cursor(0)[1]
	local query = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)

	query = query[1]
	return run_query(query)
end

function PGCLI.query_selection()
	local selection_start = vim.api.nvim_buf_get_mark(0, "<")
	local selection_end = vim.api.nvim_buf_get_mark(0, ">")

	local line1 = selection_start[1]
	local col1 = selection_start[2]
	local line2 = selection_end[1]
	local col2 = selection_end[2] + 1
	-- full line block (ShiftV), add extra line, as line1 will be == line2 for one liner
	if col2 == 2147483648 then
		line2 = line2 + 1
	end

	local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
	local query = ""

	if line2 == line1 then
		query = string.sub(lines[1], col1 + 1, col2)
	else
		query = string.sub(lines[1], col1 + 1)

		local last_line_index = line2 - line1 + 1

		for i = 2, last_line_index - 1, 1 do
			query = query .. " " .. lines[i]
		end

		local last_line = lines[last_line_index]
		query = query .. " " .. string.sub(last_line, 0, col2)
	end

	-- debug info. In case I need it again, to not have to look it up
	-- query = string.format("/* block selection %s:%s, %s:%s */", line1, col1, line2, col2) .. query
	return run_query(query)
end

function PGCLI.query_paragraph()
	local line1 = vim.api.nvim_buf_get_mark(0, "(")[1]
	local line2 = vim.api.nvim_buf_get_mark(0, ")")[1]

	local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
	local query = ""
	for _, v in pairs(lines) do
		query = query .. " " .. v
	end

	return run_query(query)
end

function PGCLI.close_latest_result()
	local buf = table.remove(query_result_buffers)
	if buf == nil then
		return
	end

	vim.cmd("bd " .. buf)
end

function PGCLI.close_all_results()
	while table.getn(query_result_buffers) > 0 do
		local buf = table.remove(query_result_buffers)

		vim.cmd("bd " .. buf)
	end
end

function PGCLI.setup(config)
	PGCLI.config = vim.tbl_extend("force", PGCLI.config, config or {})

	if PGCLI.config.database_name == "" then
		error("pgcli plugin: database_name was not provided")
	end

	local map_opts = { noremap = true, silent = true, nowait = true }
	vim.api.nvim_set_keymap(
		"n",
		PGCLI.config.execute_paragraph,
		":lua require('pgcli').query_paragraph()<CR>",
		map_opts
	)
	vim.api.nvim_set_keymap("n", PGCLI.config.execute_line, ":lua require('pgcli').query_current_line()<CR>", map_opts)
	vim.api.nvim_set_keymap(
		"v",
		PGCLI.config.execute_selection,
		":lua require('pgcli').query_selection()<CR>",
		map_opts
	)

	vim.api.nvim_set_keymap(
		"n",
		PGCLI.config.close_latest_result,
		":lua require('pgcli').close_latest_result()<CR>",
		map_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		PGCLI.config.close_all_results,
		":lua require('pgcli').close_all_results()<CR>",
		map_opts
	)
end

return PGCLI
