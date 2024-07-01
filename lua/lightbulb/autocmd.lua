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

local function update_lightbulb(bufnr, position)
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

local function render(bufnr)
  local params = lsp.util.make_range_params()
  local position = {
    row = params.range.start.line,
    col = params.range.start.character,
  }
  params.context = {
    diagnostics = lsp.diagnostic.get_line_diagnostics(bufnr),
  }

  lsp.buf_request(bufnr, 'textDocument/codeAction', params, function(_, result, _)
    if api.nvim_get_current_buf() ~= bufnr then
      return
    end

    if result and #result > 0 then
      update_lightbulb(bufnr, position)
    else
      update_lightbulb(bufnr)
    end
  end)
end

local timer = uv.new_timer()

local function update_buffer(buf)
  timer:stop()
  update_lightbulb(inrender_buf)
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
  local name = 'LightBulb'
  local g = api.nvim_create_augroup(name, { clear = true })
  api.nvim_create_autocmd('LspAttach', {
    group = g,
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
      local group_name = name .. tostring(buf)
      local ok = pcall(api.nvim_get_autocmds, { group = group_name })
      if ok then
        return
      end
      local group = api.nvim_create_augroup(group_name, { clear = true })
      api.nvim_create_autocmd('CursorMoved', {
        group = group,
        buffer = buf,
        callback = function(args)
          update_buffer(args.buf)
        end,
      })

      if not config.enable_in_insert then
        api.nvim_create_autocmd('InsertEnter', {
          group = group,
          buffer = buf,
          callback = function(args)
            update_lightbulb(args.buf)
          end,
        })
      end

      api.nvim_create_autocmd('BufLeave', {
        group = group,
        buffer = buf,
        callback = function(args)
          update_lightbulb(args.buf)
        end,
      })
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    group = g,
    callback = function(args)
      pcall(api.nvim_del_augroup_by_name, name .. tostring(args.buf))
    end,
  })
end

return {
  setup = setup_autocmd,
}
