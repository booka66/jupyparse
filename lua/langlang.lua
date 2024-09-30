local M = {}

-- Function to run LanguageTool and parse its output
function M.run_languagetool()
	local file_path = vim.fn.expand("%:p")
	local command = string.format('languagetool "%s"', file_path)

	-- Run the command and capture its output
	local output = vim.fn.system(command)

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
	local col_end = col_start + #error.context

	-- Highlight the error
	vim.api.nvim_buf_add_highlight(0, ns_id, "Error", row, col_start, col_end)

	-- Store error information for hover
	vim.api.nvim_buf_set_extmark(0, ns_id, row, col_start, {
		end_col = col_end,
		hl_group = "Error",
		data = { message = error.message, suggestion = error.suggestion },
	})
end

-- Function to show popup on hover
function M.show_popup()
	local pos = vim.api.nvim_win_get_cursor(0)
	local row, col = pos[1] - 1, pos[2]
	local ns_id = vim.api.nvim_create_namespace("languagetool")

	local extmarks = vim.api.nvim_buf_get_extmarks(0, ns_id, { row, 0 }, { row, -1 }, { details = true })

	for _, extmark in ipairs(extmarks) do
		local mark_row, mark_col, mark_details = extmark[2], extmark[3], extmark[4]
		if row == mark_row and col >= mark_col and col < mark_details.end_col then
			local data = mark_details.data
			local popup_text = string.format("Error: %s\nSuggestion: %s", data.message, data.suggestion)
			vim.lsp.util.open_floating_preview({ popup_text }, "plaintext", {
				border = "rounded",
				focusable = false,
			})
			break
		end
	end
end

-- Command to run LanguageTool
vim.api.nvim_create_user_command("LanguageTool", M.run_languagetool, {})

-- Set up hover functionality
vim.cmd([[
  augroup LanguageTool
    autocmd!
    autocmd CursorHold * lua require('langlang').show_popup()
  augroup END
]])

return M
