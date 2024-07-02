local api, lsp, fn = vim.api, vim.lsp, vim.fn
local uv = vim.uv or vim.opp
local config = require('lightbulb.config')

local inrender_row = -1
local inrender_buf = nil

local namespace = api.nvim_create_namespace('LightBulb')

local defined = false
if not defined then
  fn.sign_define(config.sign.hl, { text = config.sign.text, texthl = config.sign.hl })
  defined = true
end

---Updates current lightbulb
---@param bufnr number?
---@param position table?
local function update_extmark(bufnr, position)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  pcall(fn.sign_unplace, config.sign.hl, { id = inrender_row, buffer = bufnr })

  if not position then
    return
  end

  if config.sign.enabled then
    fn.sign_place(
      position.row + 1,
      config.sign.hl,
      config.sign.hl,
      bufnr,
      { lnum = position.row + 1, priority = config.sign.priority }
    )
  end

  if config.virtual_text.enabled then
    api.nvim_buf_set_extmark(bufnr, namespace, position.row, -1, {
      priority = config.virtual_text.priority,
      virt_text = { { config.virtual_text.text, config.virtual_text.hl } },
      virt_text_pos = 'eol',
      hl_mode = config.virtual_text.hl_mode,
    })
  end

  inrender_row = position.row + 1
  inrender_buf = bufnr
end

---Queries the LSP servers and updates the lightbulb
---@param bufnr number
local function render(bufnr)
  local params = lsp.util.make_range_params()
  params.context = {
    diagnostics = lsp.diagnostic.get_line_diagnostics(bufnr),
  }

  local position = { row = params.range.start.line, col = params.range.start.character }

  lsp.buf_request(bufnr, 'textDocument/codeAction', params, function(_, result, _)
    if api.nvim_get_current_buf() ~= bufnr then
      return
    end

    update_extmark(bufnr, (result and #result > 0 and position) or nil)
  end)
end

local timer = uv.new_timer()

---Ask @glepnir...
---@param buf number
local function update(buf)
  timer:stop()
  update_extmark(inrender_buf)
  timer:start(config.debounce, 0, function()
    timer:stop()
    vim.schedule(function()
      if api.nvim_buf_is_valid(buf) and api.nvim_get_current_buf() == buf then
        render(buf)
      end
    end)
  end)
end

local function setup_autocmd()
  local group_name = 'LightBulb'
  local group = api.nvim_create_augroup(group_name, { clear = true })
  api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(opt)
      local client = lsp.get_client_by_id(opt.data.client_id)
      if not client then
        return
      end
      if
        not client.supports_method('textDocument/codeAction')
        or vim.tbl_contains(config.ignored_clients, client.name)
      then
        return
      end

      local buf = opt.buf
      local local_group_name = group_name .. tostring(buf)
      local ok = pcall(api.nvim_get_autocmds, { group = local_group_name })
      if ok then
        return
      end
      local local_group = api.nvim_create_augroup(local_group_name, { clear = true })
      api.nvim_create_autocmd('CursorMoved', {
        group = local_group,
        buffer = buf,
        callback = function(args)
          update(args.buf)
        end,
      })

      if not config.enable_in_insert then
        api.nvim_create_autocmd('InsertEnter', {
          group = local_group,
          buffer = buf,
          callback = function(args)
            update_extmark(args.buf)
          end,
        })
      end

      api.nvim_create_autocmd('BufLeave', {
        group = local_group,
        buffer = buf,
        callback = function(args)
          update_extmark(args.buf)
        end,
      })
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    group = group,
    callback = function(args)
      pcall(api.nvim_del_augroup_by_name, group_name .. tostring(args.buf))
    end,
  })
end

return {
  setup = setup_autocmd,
}
