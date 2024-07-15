local M = {
  options = {
    debounce = 100,
    enable_in_insert = false,
    ignored_clients = {},
    sign = {
      enabled = false,
      priority = 40,
      text = '',
      hl = 'LightBulbText',
    },
    virtual_text = {
      enabled = true,
      spacing = 0,
      priority = 80,
      text = '',
      hl = 'LightBulbVirtualText',
      hl_mode = 'combine',
    },
  },
}

M.setup = function(opts) M.options = vim.tbl_deep_extend('force', M.options, opts or {}) end

setmetatable(M, {
  __index = function(self, key)
    if key ~= 'setup' then return self.options[key] end
  end,
})

return M
