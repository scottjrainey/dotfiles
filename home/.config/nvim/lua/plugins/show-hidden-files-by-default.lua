-- Wrap mini.files runtime functions so that when callers do not pass a show_hidden option,
-- show_hidden defaults to true. This does NOT change plugin defaults or override options
-- set elsewhere; it only supplies a default for the runtime API calls.
return {
  {
    "nvim-mini/mini.files",
    config = function(_, opts)
      local ok, mf = pcall(require, "mini.files")
      if not ok then
        return
      end

      -- Let the plugin set itself up with whatever opts are provided upstream.
      mf.setup(opts)

      -- Helper to default show_hidden to true when not explicitly provided.
      local function ensure_show_hidden(open_opts)
        open_opts = open_opts or {}
        if open_opts.show_hidden == nil then
          open_opts.show_hidden = true
        end
        return open_opts
      end

      -- Wrap open
      if type(mf.open) == "function" then
        local orig_open = mf.open
        mf.open = function(path, open_opts)
          return orig_open(path, ensure_show_hidden(open_opts))
        end
      end

      -- Wrap toggle (if present)
      if type(mf.toggle) == "function" then
        local orig_toggle = mf.toggle
        mf.toggle = function(path, open_opts)
          return orig_toggle(path, ensure_show_hidden(open_opts))
        end
      end

      -- Wrap search (if present)
      if type(mf.search) == "function" then
        local orig_search = mf.search
        mf.search = function(query, open_opts)
          return orig_search(query, ensure_show_hidden(open_opts))
        end
      end
    end,
  },
}
