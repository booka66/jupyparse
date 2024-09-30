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
	for line in output:gmatch("[^\r\n]+") do
		local line_num, col, rule_id = line:match("(%d+)%.) Line (%d+), column (%d+), Rule ID: (.+)")
		local message = line:match("Message: (.+)")
		local suggestion = line:match("Suggestion: (.+)")
		local context = line:match("%.%.%.(.-)%.%.%.")

		if line_num and col then
			-- New error found, process the previous one if it exists
			if current_error.row then
				M.highlight_error(ns_id, current_error)
			end
			current_error = {
				row = tonumber(line_num) - 1,
				col = tonumber(col) - 1,
				rule_id = rule_id,
				message = "",
				suggestion = "",
				context = "",
			}
		end

		if message then
			current_error.message = message
		end
		if suggestion then
			current_error.suggestion = suggestion
		end
		if context then
			current_error.context = context
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

	-- Add virtual text for the error
	vim.api.nvim_buf_set_extmark(0, ns_id, row, col_start, {
		virt_text = { { error.message .. " (Suggestion: " .. error.suggestion .. ")", "Error" } },
		virt_text_pos = "eol",
	})

	-- Highlight the error
	vim.api.nvim_buf_add_highlight(0, ns_id, "Error", row, col_start, col_end)
end

-- Command to run LanguageTool
vim.api.nvim_create_user_command("LanguageTool", M.run_languagetool, {})

return M
