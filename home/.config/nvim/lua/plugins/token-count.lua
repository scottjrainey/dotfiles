return {
  {
    "3ZsForInsomnia/token-count.nvim",
    opts = {
      model = "claude-4-opus",
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local ok, tc_lualine = pcall(require, "token-count.integrations.lualine")
      if ok then
        table.insert(opts.sections.lualine_x, 1, tc_lualine.current_buffer)
      end
    end,
  },
}
