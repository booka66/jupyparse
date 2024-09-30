local M = {}

-- Table to store error information
M.error_info = {}

-- Timer for delayed popup
M.popup_timer = nil

-- Function to run LanguageTool and parse its output
function M.run_languagetool()
	local file_path = vim.fn.expand("%:p")
	local command = string.format('languagetool "%s"', file_path)

	-- Run the command and capture its output
	local output = vim.fn.system(command)

	-- Clear previous error information
	M.error_info = {}

	-- Parse the output and highlight errors
	M.parse_and_highlight(output)
end

-- Function to parse LanguageTool output and highlight errors
function M.parse_and_highlight(output)
	local ns_id = vim.api.nvim_create_namespace("languagetool")
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

	local current_error = {}
	local in_error = false

	for line in output:gmatch("[^\r\n]+") do
		if line:match("^%d+%.%)") then
			-- New error found, process the previous one if it exists
			if current_error.row then
				M.highlight_error(ns_id, current_error)
			end

			local line_num, col = line:match("Line (%d+), column (%d+)")
			current_error = {
				row = tonumber(line_num) - 1,
				col = tonumber(col) - 1,
				message = "",
				suggestion = "",
				context = "",
			}
			in_error = true
		elseif in_error then
			if line:match("^Message:") then
				current_error.message = line:match("^Message: (.+)")
			elseif line:match("^Suggestion:") then
				current_error.suggestion = line:match("^Suggestion: (.+)")
			elseif line:match("^%.%.%.") then
				current_error.context = line:match("%.%.%.(.-%.%.%.)")
				in_error = false
			end
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

	local col_end = math.min(col_start + #error.context, #line)

	-- Highlight the error
	vim.api.nvim_buf_add_highlight(0, ns_id, "Error", row, col_start, col_end)

	-- Store error information
	local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, row, col_start, {
		end_col = col_end,
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
			return
		end
	end

	-- If we're not over an error, close any existing popups
	vim.api.nvim_command("close")
end

-- Function to handle cursor movement
function M.on_cursor_move()
	if M.popup_timer then
		vim.fn.timer_stop(M.popup_timer)
	end
	M.popup_timer = vim.fn.timer_start(100, function()
		M.show_popup()
	end)
end

-- Command to run LanguageTool
vim.api.nvim_create_user_command("LanguageTool", M.run_languagetool, {})

-- Set up hover functionality
vim.cmd([[
  augroup LanguageTool
    autocmd!
    autocmd CursorMoved * lua require('langlang').on_cursor_move()
    autocmd CursorMovedI * lua require('langlang').on_cursor_move()
  augroup END
]])

return M
