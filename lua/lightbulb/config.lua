local M = {
  config = {
    debounce = 100,
    enable_in_insert = true,
    ignored_clients = {},
    sign = {
      enabled = false,
      priority = 40,
      text = '󰌵',
      hl = 'LightBulbText',
    },
    virtual_text = {
      enabled = true,
      priority = 10,
      text = '󰌵',
      hl = 'LightBulbVirtualText',
      hl_mode = 'combine',
    },
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

setmetatable(M, {
  __index = function(self, key)
    if key ~= 'setup' then
      return self.config[key]
    end
  end,
})

return M
