local M = {}

-- Table to store error information
M.error_info = {}

-- Function to run LanguageTool asynchronously and parse its output
function M.run_languagetool()
	local file_path = vim.fn.expand("%:p")
	local command = string.format('languagetool "%s"', file_path)

	-- Clear previous error information
	M.error_info = {}

	-- Run the command asynchronously
	vim.fn.jobstart(command, {
		on_stdout = function(_, data)
			if data then
				M.parse_and_highlight(table.concat(data, "\n"))
			end
		end,
		on_stderr = function(_, data)
			if data then
				-- print("LanguageTool error: " .. table.concat(data, "\n"))
			end
		end,
		stdout_buffered = true,
		stderr_buffered = true,
	})
end

-- Function to parse LanguageTool output and highlight errors
function M.parse_and_highlight(output)
	local ns_id = vim.api.nvim_create_namespace("languagetool")
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
	local current_error = {}
	for line in output:gmatch("[^\r\n]+") do
		if line:match("^%d+%.%)") then
			-- New error found, process the previous one if it exists
			if current_error.row then
				M.highlight_error(ns_id, current_error)
			end
			local line_num, col = line:match("Line (%d+), column (%d+)")
			current_error = {
				row = tonumber(line_num) - 1, -- Lua is 0-indexed
				col = tonumber(col) - 1, -- Lua is 0-indexed
				message = "",
				suggestion = "",
			}
		elseif line:match("^Message:") then
			current_error.message = line:match("^Message: (.+)")
		elseif line:match("^Suggestion:") then
			current_error.suggestion = line:match("^Suggestion: (.+)")
		end
	end
	-- Process the last error
	if current_error.row then
		M.highlight_error(ns_id, current_error)
	end
end

-- Function to highlight a single error
function M.highlight_error(ns_id, error)
	local row = error.row
	local col_start = error.col
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
	if not line then
		return
	end
	-- Find the end of the word starting at col_start
	local col_end = col_start
	while col_end < #line and line:sub(col_end + 1, col_end + 1):match("%w") do
		col_end = col_end + 1
	end
	-- Highlight only the specific word or phrase
	vim.api.nvim_buf_add_highlight(0, ns_id, "Error", row, col_start, col_end + 1)
	-- Store error information
	local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, row, col_start, {
		end_col = col_end + 1,
		strict = false,
	})
	-- Store error information in our table
	M.error_info[extmark_id] = {
		message = error.message,
		suggestion = error.suggestion,
	}
end

-- Function to show popup on hover
function M.show_popup()
	local pos = vim.api.nvim_win_get_cursor(0)
	local row, col = pos[1] - 1, pos[2]
	local ns_id = vim.api.nvim_create_namespace("languagetool")
	local extmarks = vim.api.nvim_buf_get_extmarks(0, ns_id, { row, 0 }, { row, -1 }, { details = true })
	for _, extmark in ipairs(extmarks) do
		local mark_id, mark_row, mark_col, mark_details = extmark[1], extmark[2], extmark[3], extmark[4]
		if row == mark_row and col >= mark_col and col < (mark_details.end_col or mark_col) then
			local error_data = M.error_info[mark_id]
			if error_data then
				local popup_text = string.format("Error: %s\nSuggestion: %s", error_data.message, error_data.suggestion)
				vim.lsp.util.open_floating_preview({ popup_text }, "plaintext", {
					border = "rounded",
					focusable = false,
				})
			end
			break
		end
	end
end

-- Command to run LanguageTool
vim.api.nvim_create_user_command("LanguageTool", M.run_languagetool, {})

-- Set up hover functionality and autocommand for .tex files
vim.cmd([[
  augroup LanguageTool
    autocmd!
    autocmd CursorHold * lua require('langlang').show_popup()
    autocmd BufWritePost *.tex lua require('langlang').run_languagetool()
  augroup END
]])

return M
