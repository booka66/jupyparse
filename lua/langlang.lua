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

	for line in output:gmatch("[^\r\n]+") do
		local line_num, col, message = line:match("Line (%d+), column (%d+).*Message: (.+)")
		if line_num and col and message then
			local row = tonumber(line_num) - 1
			local col_start = tonumber(col) - 1
			local col_end = col_start + 1 -- Highlight only one character for simplicity

			-- Add virtual text for the error
			vim.api.nvim_buf_set_extmark(0, ns_id, row, col_start, {
				virt_text = { { message, "Error" } },
				virt_text_pos = "eol",
			})

			-- Highlight the error
			vim.api.nvim_buf_add_highlight(0, ns_id, "Error", row, col_start, col_end)
		end
	end
end

-- Command to run LanguageTool
vim.api.nvim_create_user_command("LanguageTool", M.run_languagetool, {})

return M
