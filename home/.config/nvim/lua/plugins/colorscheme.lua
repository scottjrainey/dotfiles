-- Let Ghostty's translucent, blurred background show through Neovim.
--
-- Without this, the colorscheme paints its own opaque Normal background over
-- every cell, so launching nvim turns the whole window solid until you quit.
-- `transparent` stops it painting Normal; the two `styles` entries do the same
-- for sidebars (neo-tree, etc.) and floating windows, so popups don't sit on
-- opaque rectangles over the wallpaper.
--
-- Kun's dotfiles achieve this with rose-pine's `styles.transparency`; these are
-- the tokyonight equivalents, so LazyVim's default tokyonight-moon colours are
-- kept. LazyVim already declares this plugin with `opts = { style = "moon" }`
-- and lazy.nvim deep-merges opts, so the moon variant survives this override.
--
-- Pairs with background-opacity / background-blur in .config/ghostty/config.
-- Revert any of the three to `false` / "dark" if a surface reads better opaque.
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
