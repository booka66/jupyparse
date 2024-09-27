local M = {}

-- Function to parse the Python file and extract cell information
local function parse_notebook(file_path)
	local cells = {}
	local current_cell = { content = {}, type = "code" }
	for line in io.lines(file_path) do
		if line:match("^# %%") then
			-- New cell marker
			if #current_cell.content > 0 then
				table.insert(cells, current_cell)
				current_cell = { content = {}, type = "code" }
			end
			if line:match("^# %% %[markdown%]") then
				current_cell.type = "markdown"
			end
		else
			table.insert(current_cell.content, line)
		end
	end
	if #current_cell.content > 0 then
		table.insert(cells, current_cell)
	end
	return cells
end

-- Function to render the notebook in a new buffer
local function render_notebook(cells)
	vim.cmd("new")
	local buf = vim.api.nvim_get_current_buf()
	for i, cell in ipairs(cells) do
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "--- Cell " .. i .. " (" .. cell.type .. ") ---" })
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, cell.content)
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
	end
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "notebook"
end

-- Function to open and render a notebook file
function M.open_notebook(file_path)
	local cells = parse_notebook(file_path)
	render_notebook(cells)
end

-- New function to open the notebook for the current buffer
function M.open_current_notebook()
	local current_file = vim.fn.expand("%:p")
	if current_file ~= "" then
		M.open_notebook(current_file)
	else
		print("No file in current buffer")
	end
end

-- Set up the plugin
function M.setup()
	-- Command to open a notebook file
	vim.api.nvim_create_user_command("OpenNotebook", function(opts)
		M.open_notebook(opts.args)
	end, { nargs = 1, complete = "file" })

	-- New command to open the notebook for the current buffer
	vim.api.nvim_create_user_command("OpenCurrentNotebook", function()
		M.open_current_notebook()
	end, {})
end

return M
