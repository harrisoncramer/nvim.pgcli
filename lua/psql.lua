local u = require("util")

local SETTINGS = {
	connection = {
		database = "postgres",
		host = "localhost",
		port = 5432,
		password = "postgres",
		username = "postgres",
	},
	hash_algorithm = "sha256",
}

return {
	yank_cell = function()
		vim.api.nvim_feedkeys("T|vt|y", "n", false)
		local selection = u.get_visual_selection()
		return selection:match("^(.*%S)%s*$")
	end,
	query_current_line = function()
		local line_number = vim.api.nvim_win_get_cursor(0)[1]
		local query = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)

		query = query[1]
		return u.run_query(query, SETTINGS)
	end,
	query_selection = function()
		-- This ugly utility will hopefully be resolved in the future...
		-- https://github.com/neovim/neovim/pull/13896
		-- Until then: https://www.reddit.com/r/neovim/comments/p4u4zy/how_to_pass_visual_selection_range_to_lua_function/
		local selection = u.get_visual_selection()

		local query = ""
		for _, v in pairs(selection) do
			query = query .. " " .. v .. " "
		end
		return u.run_query(query, SETTINGS)
	end,
	query_paragraph = function()
		local line1 = vim.api.nvim_buf_get_mark(0, "(")[1]
		local line2 = vim.api.nvim_buf_get_mark(0, ")")[1]

		local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
		local query = ""
		for _, v in pairs(lines) do
			query = query .. " " .. v .. " "
		end

		return u.run_query(query, SETTINGS)
	end,
	setup = function(config)
		SETTINGS = vim.tbl_extend("force", SETTINGS, config or {})

		vim.api.nvim_create_user_command("PSQL", function(opts)
			local db = opts.args
			local var_table_exists, var_table = pcall(require, "psql." .. db)

			-- User provided an invalid module, exit.
			if not var_table_exists then
				print("Could not find config file at " .. vim.fn.stdpath("config") .. "/lua/psql/" .. db .. ".lua")

				print("Please create a lua module and add your config table.")
				return
			end

			-- Module doesn't contain a password, configure PSQL with 'postgres'
			if not var_table.connection.password then
				require("psql").setup(var_table)
				print("No password supplied, using 'postgres'")
				var_table.connection.password = "postgres"
				require("psql").setup(var_table)
				return
			end

			-- Module contains hashed password, validate user input
			vim.ui.input({ prompt = "Enter password for " .. db .. ": " }, function(input)
				vim.cmd([[ :call feedkeys(':', 'nx') ]])
				local hashed_password = u.hash_password(input, SETTINGS.hash_algorithm)
				if var_table.connection.password ~= hashed_password then
					print("The password is invalid")
					return
				else
					var_table.connection.password = input
					require("psql").setup(var_table)
					print("PSQL set to " .. db .. "!")
				end
			end)
		end, { nargs = 1 })
	end,
}
