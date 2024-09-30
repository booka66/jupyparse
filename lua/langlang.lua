-- langlang.lua

local M = {}

-- Configuration
M.config = {
	languagetool_cmd = "/opt/homebrew/bin/languagetool",
	filetypes = { "tex" },
	auto_check = false,
	signs = {
		enable = true,
		priority = 10,
	},
}

-- Initialize the plugin
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create highlight group for grammar issues
	vim.cmd([[
    highlight default link LanguageToolGrammarError SpellBad
  ]])

	-- Create sign for grammar issues
	if M.config.signs.enable then
		vim.fn.sign_define("LanguageToolGrammarError", {
			text = "≈",
			texthl = "LanguageToolGrammarError",
			linehl = "LanguageToolGrammarError",
		})
	end

	-- Set up autocommands
	vim.cmd([[
    augroup LanguageTool
      autocmd!
      autocmd BufWritePost *.tex lua require('languagetool').check_grammar()
    augroup END
  ]])

	-- Add command to manually trigger grammar check
	vim.api.nvim_create_user_command("LanguageToolCheck", M.check_grammar, {})
end

-- Function to check grammar
function M.check_grammar()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype

	if not vim.tbl_contains(M.config.filetypes, filetype) then
		return
	end

	local filename = vim.fn.expand("%:p")
	local cmd = string.format("%s -l en-US %s", M.config.languagetool_cmd, filename)

	-- Clear existing signs and highlights
	M.clear_highlights(bufnr)

	-- Run LanguageTool
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			M.parse_output(bufnr, data)
		end,
		on_exit = function()
			vim.cmd("redraw")
		end,
	})
end

-- Function to parse LanguageTool output
function M.parse_output(bufnr, data)
	for _, line in ipairs(data) do
		local row, col, message = line:match("(%d+)%.(%d+): (.+)")
		if row and col and message then
			row = tonumber(row)
			col = tonumber(col)

			-- Add highlight
			vim.api.nvim_buf_add_highlight(bufnr, -1, "LanguageToolGrammarError", row - 1, col - 1, -1)

			-- Add sign
			if M.config.signs.enable then
				vim.fn.sign_place(0, "LanguageTool", "LanguageToolGrammarError", bufnr, {
					lnum = row,
					priority = M.config.signs.priority,
				})
			end
		end
	end
end

-- Function to clear highlights and signs
function M.clear_highlights(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
	if M.config.signs.enable then
		vim.fn.sign_unplace("LanguageTool", { buffer = bufnr })
	end
end

return M
