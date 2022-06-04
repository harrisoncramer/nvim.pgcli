local hash = require("hash.init")

local query_result_buffers = {}
local function run_query(query, config)
	-- strip leading and trailing spaces
	query = string.gsub(query, "^%s*(.-)%s*$", "%1")

	if query == nil or query == "" then
		print("PSQL: Query is empty")
		return
	end

	-- open horizontally split new window
	vim.cmd([[
    if bufwinnr('__SQL__') == -1
      execute 'split ' . '__SQL__'
      setlocal buftype=nofile
      setlocal bufhidden=hide
      setlocal noswapfile
      set ft=sql
    else
      execute bufwinnr('__SQL__') . 'wincmd w'
    endif
  ]])

	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)

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
	local command = ""
	if config.connection.password then
		command = "PGPASSWORD=" .. config.connection.password
	end
	local result = vim.fn.systemlist(
		command
			.. " psql "
			.. " -h "
			.. config.connection.host
			.. " -p "
			.. config.connection.port
			.. " -U "
			.. config.connection.username
			.. " -d "
			.. config.connection.database
			.. " -f "
			.. tmp_file
	)

	os.remove(tmp_file)

	-- replace result buffer with query results
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, { query, "" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, true, result)
	vim.cmd([[ setlocal readonly ]])
end

local function hash_password(password, algo)
	algo = algo or "sha256"
	local hashed = hash[algo](password)
	return hashed
end

local function get_visual_selection()
	local modeInfo = vim.api.nvim_get_mode()
	local mode = modeInfo.mode

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cline, ccol = cursor[1], cursor[2]
	local vline, vcol = vim.fn.line("v"), vim.fn.col("v")

	local sline, scol
	local eline, ecol
	if cline == vline then
		if ccol <= vcol then
			sline, scol = cline, ccol
			eline, ecol = vline, vcol
			scol = scol + 1
		else
			sline, scol = vline, vcol
			eline, ecol = cline, ccol
			ecol = ecol + 1
		end
	elseif cline < vline then
		sline, scol = cline, ccol
		eline, ecol = vline, vcol
		scol = scol + 1
	else
		sline, scol = vline, vcol
		eline, ecol = cline, ccol
		ecol = ecol + 1
	end

	if mode == "V" or mode == "CTRL-V" or mode == "\22" then
		scol = 1
		ecol = nil
	end

	local lines = vim.api.nvim_buf_get_lines(0, sline - 1, eline, 0)
	if #lines == 0 then
		return
	end

	local startText, endText
	if #lines == 1 then
		startText = string.sub(lines[1], scol, ecol)
	else
		startText = string.sub(lines[1], scol)
		endText = string.sub(lines[#lines], 1, ecol)
	end

	local selection = { startText }
	if #lines > 2 then
		vim.list_extend(selection, vim.list_slice(lines, 2, #lines - 1))
	end
	table.insert(selection, endText)

	return selection
end

return {
	run_query = run_query,
	hash_password = hash_password,
	get_visual_selection = get_visual_selection,
}
