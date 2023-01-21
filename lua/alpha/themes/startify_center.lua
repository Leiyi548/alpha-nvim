local if_nil = vim.F.if_nil
local fnamemodify = vim.fn.fnamemodify
local filereadable = vim.fn.filereadable

local cow = {
  '        \\   ^__^',
  '         \\  (oo)\\_______',
  '            (__)\\       )\\/\\',
  '                ||----w |',
  '                ||     ||',
}

quotes = require('alpha.quotes')
---Returns a random programming quote
---@return table: Lines of text for the quote
local function get_random_quote()
  math.randomseed(os.clock())
  local index = math.random() * #quotes
  return quotes[math.floor(index) + 1]
end

---return longest line length
---@param lines table
---@return number longest
local function get_longest_line_length(lines)
  local longest = 0
  for _, line in ipairs(lines) do
    if vim.fn.strdisplaywidth(line) > longest then
      longest = vim.fn.strdisplaywidth(line)
    end
  end
  return longest
end

local quote = get_random_quote()
while true do
  if get_longest_line_length(quote) <= vim.o.columns - 15 then
    break
  end
  quote = get_random_quote()
end

local length = get_longest_line_length(quote) + 4

local default_header_tbl = {}

table.insert(quote, 1, '')
quote[#quote + 1] = ''

table.insert(default_header_tbl, '▛' .. string.rep('▀', length - 2) .. '▜')
local function spaces(amount)
  return string.rep(' ', amount)
end

for _, line in ipairs(quote) do
  table.insert(default_header_tbl, '▌' .. ' ' .. line .. spaces(length - 3 - #line) .. '▐')
end
table.insert(default_header_tbl, '▙' .. string.rep('▄', length - 2) .. '▟')

for _, line in ipairs(cow) do
  default_header_tbl[#default_header_tbl + 1] = line
end

local default_header = {
  type = 'text',
  val = default_header_tbl,
  opts = {
    hl = 'Type',
    position = 'center',
    shrink_margin = false,
    -- wrap = "overflow";
  },
}

local default_mru_header = {
  type = 'text',
  val = 'MRU ' .. vim.fn.getcwd(),
  opts = {
    hl = 'keyword',
    position = 'center',
    shrink_margin = false,
    -- wrap = "overflow";
  },
}

local leader = 'SPC'

--- @param sc string
--- @param txt string
--- @param keybind string? optional
--- @param keybind_opts table? optional
local function button(sc, txt, keybind, keybind_opts)
  local sc_ = sc:gsub('%s', ''):gsub(leader, '<leader>')

  local opts = {
    position = 'center',
    shortcut = '[' .. sc .. '] ',
    cursor = 1,
    width = 60,
    align_shortcut = 'left',
    hl_shortcut = { { 'Operator', 0, 1 }, { 'Number', 1, #sc + 1 }, { 'Operator', #sc + 1, #sc + 2 } },
    shrink_margin = false,
  }
  if keybind then
    keybind_opts = if_nil(keybind_opts, { noremap = true, silent = true, nowait = true })
    opts.keymap = { 'n', sc_, keybind, { noremap = false, silent = true, nowait = true } }
  end

  local function on_press()
    local key = vim.api.nvim_replace_termcodes(keybind .. '<Ignore>', true, false, true)
    vim.api.nvim_feedkeys(key, 't', false)
  end

  return {
    type = 'button',
    val = txt,
    on_press = on_press,
    opts = opts,
  }
end

local nvim_web_devicons = {
  enabled = true,
  highlight = true,
}

local function get_extension(fn)
  local match = fn:match('^.+(%..+)$')
  local ext = ''
  if match ~= nil then
    ext = match:sub(2)
  end
  return ext
end

local function icon(fn)
  local nwd = require('nvim-web-devicons')
  local ext = get_extension(fn)
  return nwd.get_icon(fn, ext, { default = true })
end

local function file_button(fn, sc, short_fn, autocd)
  short_fn = if_nil(short_fn, fn)
  local ico_txt
  local fb_hl = {}
  if nvim_web_devicons.enabled then
    local ico, hl = icon(fn)
    local hl_option_type = type(nvim_web_devicons.highlight)
    if hl_option_type == 'boolean' then
      if hl and nvim_web_devicons.highlight then
        table.insert(fb_hl, { hl, 0, 1 })
      end
    end
    if hl_option_type == 'string' then
      table.insert(fb_hl, { nvim_web_devicons.highlight, 0, 1 })
    end
    ico_txt = ico .. '  '
  else
    ico_txt = ''
  end
  local cd_cmd = (autocd and ' | cd %:p:h' or '')
  local file_button_el = button(sc, ico_txt .. short_fn, '<cmd>e ' .. fn .. cd_cmd .. ' <CR>')
  local fn_start = short_fn:match('.*[/\\]')
  if fn_start ~= nil then
    table.insert(fb_hl, { 'Comment', #ico_txt - 2, #fn_start + #ico_txt - 2 })
  end
  file_button_el.opts.hl = fb_hl
  return file_button_el
end

local default_mru_ignore = { 'gitcommit' }

local mru_opts = {
  ignore = function(path, ext)
    return (string.find(path, 'COMMIT_EDITMSG')) or (vim.tbl_contains(default_mru_ignore, ext))
  end,
  autocd = false,
  special_shortcuts = { 'a', 's', 'd' },
}

--- @param start number
--- @param cwd string? optional
--- @param items_number number? optional number of items to generate, default = 10
local function mru(start, cwd, items_number, opts)
  opts = opts or mru_opts
  items_number = if_nil(items_number, 10)
  local oldfiles = {}
  for _, v in pairs(vim.v.oldfiles) do
    if #oldfiles == items_number then
      break
    end
    local cwd_cond
    if not cwd then
      cwd_cond = true
    else
      cwd_cond = vim.startswith(v, cwd)
    end
    local ignore = (opts.ignore and opts.ignore(v, get_extension(v))) or false
    if (filereadable(v) == 1) and cwd_cond and not ignore then
      oldfiles[#oldfiles + 1] = v
    end
  end

  local tbl = {}
  for i, fn in ipairs(oldfiles) do
    local short_fn
    if cwd then
      short_fn = fnamemodify(fn, ':.')
    else
      short_fn = fnamemodify(fn, ':~')
    end
    if i <= #mru_opts.special_shortcuts then
      local file_button_el = file_button(fn, mru_opts.special_shortcuts[i], short_fn, opts.autocd)
      tbl[i] = file_button_el
    else
      local file_button_el =
        file_button(fn, tostring(i + start - 1 - #mru_opts.special_shortcuts), short_fn, opts.autocd)
      tbl[i] = file_button_el
    end
  end
  return {
    type = 'group',
    val = tbl,
    opts = {},
  }
end

local section = {
  header = default_header,
  mru_header = default_mru_header,
  top_buttons = {
    type = 'group',
    val = {
      button('e', 'New file', '<cmd>ene <CR>'),
    },
  },
  -- note about MRU: currently this is a function,
  -- since that means we can get a fresh mru
  -- whenever there is a DirChanged. this is *really*
  -- inefficient on redraws, since mru does a lot of I/O.
  -- should probably be cached, or maybe figure out a way
  -- to make it a reference to something mutable
  -- and only mutate that thing on DirChanged
  mru = {
    type = 'group',
    val = {
      { type = 'padding', val = 1 },
      { type = 'text', val = 'MRU', opts = { hl = 'SpecialComment' } },
      { type = 'padding', val = 1 },
      {
        type = 'group',
        val = function()
          return { mru(10) }
        end,
      },
    },
  },
  mru_cwd = {
    type = 'group',
    val = {
      { type = 'padding', val = 1 },
      {
        type = 'group',
        val = function()
          return { mru(0, vim.fn.getcwd()) }
        end,
        opts = { shrink_margin = false },
      },
    },
  },
  bottom_buttons = {
    type = 'group',
    val = {
      button('q', 'Quit', '<cmd>q <CR>'),
    },
  },
  footer = {
    type = 'group',
    val = {},
  },
}

local config = {
  layout = {
    { type = 'padding', val = 1 },
    section.header,
    { type = 'padding', val = 1 },
    section.mru_header,
    { type = 'padding', val = 2 },
    section.top_buttons,
    section.mru_cwd,
    { type = 'padding', val = 1 },
    section.bottom_buttons,
    section.footer,
  },
  opts = {
    margin = 3,
    redraw_on_resize = false,
    setup = function()
      vim.api.nvim_create_autocmd('DirChanged', {
        pattern = '*',
        callback = function()
          require('alpha').redraw()
        end,
      })
    end,
  },
}

return {
  icon = icon,
  button = button,
  file_button = file_button,
  mru = mru,
  mru_opts = mru_opts,
  section = section,
  config = config,
  -- theme config
  nvim_web_devicons = nvim_web_devicons,
  leader = leader,
  -- deprecated
  opts = config,
}
