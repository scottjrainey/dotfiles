return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- Keep LazyVim's preset behavior if you're using it
      -- (optional; remove if you already set this elsewhere)
      -- preset = "lazy",

      -- Key change: disable anti_conceal so the cursor line doesn't
      -- re-render the top of lists/code blocks differently
      anti_conceal = {
        enabled = false,
      },

      -- Keep the signcolumn as clean as possible
      heading = {
        sign = false,
      },
      code = {
        sign = false,
      },
    },
  },
}
