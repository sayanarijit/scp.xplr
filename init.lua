---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local function quote(str)
  return "'" .. string.gsub(str, "'", [['"'"']]) .. "'"
end

local function parse_hosts()
  local home = os.getenv("HOME")
  local user_config_path = home .. "/" .. ".ssh/config"
  local global_config_path = "/etc/ssh/ssh_config"
  local config_paths = { user_config_path, global_config_path }
  local hosts = {}

  for _, config_path in ipairs(config_paths) do
    for line in io.lines(config_path) do
      if string.sub(line, 1, 5) == "Host " then
        local host = string.sub(line, 6, -1)
        table.insert(hosts, host)
      end
    end
  end

  return hosts
end

local state = {}

local function init_state()
  state.top = 1
  state.cursor = 1
  state.dest_hist_cursor = 1
  state.destinations = {}
  state.hosts = parse_hosts()
end

local function count_destinations()
  local count = 0
  for _, _ in pairs(state.destinations) do
    count = count + 1
  end

  return count
end

local function format_line(num)
  local host = state.hosts[num]
  local dest = state.destinations[num]
  if num == state.cursor and dest then
    return "█ " .. num .. ". " .. host .. ":" .. quote(dest)
  elseif num == state.cursor then
    return "▌ " .. num .. ". " .. host
  elseif dest then
    return "▐ " .. num .. ". " .. host .. ":" .. quote(dest)
  else
    return "  " .. num .. ". " .. host
  end
end

local function deepcopy(obj)
  if type(obj) ~= "table" then
    return obj
  end
  local res = {}
  for k, v in pairs(obj) do
    res[deepcopy(k)] = deepcopy(v)
  end
  return res
end

local scp_layout = {
  CustomContent = {
    title = "scp",
    body = { DynamicList = { render = "custom.scp.render" } },
  },
}

local function hijack_table(layout)
  if layout == "Table" then
    return scp_layout
  elseif layout.Horizontal or layout.Vertical then
    local res = deepcopy(layout)
    for _, v in pairs(res) do
      for i, l in ipairs(v.splits) do
        v.splits[i] = hijack_table(l)
      end
    end
    return res
  else
    return layout
  end
end

local function setup(args)
  args = args or {}
  args.key = args.key or "S"
  args.mode = args.mode or xplr.config.modes.builtin.selection_ops
  args.scp_command = args.scp_command or "scp -r"

  if args.non_interactive == nil then
    args.non_interactive = false
  end

  if args.keep_selection == nil then
    args.keep_selection = false
  end

  if type(args.mode) == "string" then
    args.mode = xplr.config.modes.builtin[args.mode]
  end

  args.mode.key_bindings.on_key[args.key] = {
    help = "send via scp",
    messages = {
      "PopMode",
      { CallLuaSilently = "custom.scp.init" },
    },
  }

  xplr.config.modes.custom.scp_select_host = {
    name = "select hosts",
    layout = hijack_table(xplr.config.layouts.builtin.default),
    key_bindings = {
      on_key = {
        up = {
          help = "go up",
          messages = {
            { CallLuaSilently = "custom.scp.go_up" },
          },
        },
        down = {
          help = "go down",
          messages = {
            { CallLuaSilently = "custom.scp.go_down" },
          },
        },
        g = {
          help = "go to top",
          messages = {
            { CallLuaSilently = "custom.scp.go_top" },
          },
        },
        G = {
          help = "go to bottom",
          messages = {
            { CallLuaSilently = "custom.scp.go_bottom" },
          },
        },
        space = {
          help = "toggle select",
          messages = {
            { CallLuaSilently = "custom.scp.toggle_select" },
          },
        },
        ["+"] = {
          help = "add host",
          messages = {
            { SwitchModeCustom = "scp_add_host" },
            { SetInputBuffer = "" },
            { SetInputPrompt = "[user@]host[:port]: " },
          },
        },
        ["ctrl-a"] = {
          help = "toggle select all",
          messages = {
            { CallLuaSilently = "custom.scp.toggle_select_all" },
          },
        },
        enter = {
          help = "send",
          messages = {
            { CallLua = "custom.scp.send" },
          },
        },
        esc = {
          messages = {
            "PopMode",
          },
        },
        ["ctrl-c"] = {
          messages = {
            "Terminate",
          },
        },
      },
      on_number = {
        help = "to number",
        messages = {
          { SwitchModeCustom = "scp_goto_number" },
          "UpdateInputBufferFromKey",
        },
      },
    },
  }

  xplr.config.modes.custom.scp_select_host.key_bindings.on_key.k =
    xplr.config.modes.custom.scp_select_host.key_bindings.on_key.up

  xplr.config.modes.custom.scp_select_host.key_bindings.on_key.j =
    xplr.config.modes.custom.scp_select_host.key_bindings.on_key.down

  xplr.config.modes.custom.scp_select_host.key_bindings.on_key[":"] =
    xplr.config.modes.custom.scp_select_host.key_bindings.on_key.space

  xplr.config.modes.custom.scp_goto_number = {
    name = "go to number",
    layout = hijack_table(xplr.config.layouts.builtin.default),
    key_bindings = {
      on_key = {
        enter = {
          help = "go",
          messages = {
            { CallLuaSilently = "custom.scp.go_to_number" },
            "PopMode",
          },
        },
        up = {
          help = "go up",
          messages = {
            { CallLuaSilently = "custom.scp.go_up_number" },
            "PopMode",
          },
        },
        down = {
          help = "go down",
          messages = {
            { CallLuaSilently = "custom.scp.go_down_number" },
            "PopMode",
          },
        },
        esc = {
          messages = {
            "PopMode",
          },
        },
        ["ctrl-c"] = {
          messages = {
            "Terminate",
          },
        },
      },
      on_number = {
        messages = {
          "UpdateInputBufferFromKey",
        },
      },
      on_navigation = {
        messages = {
          "UpdateInputBufferFromKey",
        },
      },
      default = {
        messages = {},
      },
    },
  }

  xplr.config.modes.custom.scp_add_host = {
    name = "add host",
    layout = hijack_table(xplr.config.layouts.builtin.default),
    key_bindings = {
      on_key = {
        enter = {
          help = "submit",
          messages = {
            { CallLuaSilently = "custom.scp.add_host" },
          },
        },
        esc = {
          messages = {
            "PopMode",
          },
        },
        ["ctrl-c"] = {
          messages = {
            "Terminate",
          },
        },
      },
      default = {
        messages = {
          "UpdateInputBufferFromKey",
        },
      },
    },
  }

  xplr.config.modes.custom.scp_enter_dest = {
    name = "enter destination",
    layout = hijack_table(xplr.config.layouts.builtin.default),
    key_bindings = {
      on_key = {
        up = {
          help = "prev value",
          messages = {
            { CallLuaSilently = "custom.scp.prev_value" },
          },
        },
        down = {
          help = "next value",
          messages = {
            { CallLuaSilently = "custom.scp.next_value" },
          },
        },
        esc = {
          messages = {
            "PopMode",
          },
        },
        ["ctrl-c"] = {
          messages = {
            "Terminate",
          },
        },
        enter = {
          help = "submit",
          messages = {
            { CallLuaSilently = "custom.scp.update_dest" },
          },
        },
      },
      default = {
        messages = {
          "UpdateInputBufferFromKey",
        },
      },
    },
  }

  xplr.config.modes.custom.scp_enter_common_dest = deepcopy(
    xplr.config.modes.custom.scp_enter_dest
  )

  xplr.config.modes.custom.scp_enter_common_dest.name = "enter common destination"
  xplr.config.modes.custom.scp_enter_common_dest.key_bindings.on_key.enter.messages = {
    { CallLuaSilently = "custom.scp.update_all_dest" },
  }

  xplr.fn.custom.scp = {}

  xplr.fn.custom.scp.init = function(app)
    if #app.selection == 0 then
      return {
        { LogError = "scp: no file selected" },
      }
    end

    init_state()

    return {
      { SwitchModeCustom = "scp_select_host" },
    }
  end

  xplr.fn.custom.scp.render = function(ctx)
    local height = ctx.layout_size.height - 3
    if state.cursor < state.top then
      state.top = state.cursor
    elseif state.cursor >= state.top + height then
      state.top = state.cursor - height
    end

    local bottom = state.top + height

    local lines = {}
    for i, _ in ipairs(state.hosts) do
      if i >= state.top then
        local line = format_line(i)
        table.insert(lines, line)
        if i >= bottom then
          break
        end
      end
    end

    return lines
  end

  xplr.fn.custom.scp.go_up = function(_)
    if state.cursor == 1 then
      state.cursor = #state.hosts
    else
      state.cursor = state.cursor - 1
    end
  end

  xplr.fn.custom.scp.go_down = function(_)
    if state.cursor == #state.hosts then
      state.cursor = 1
    else
      state.cursor = state.cursor + 1
    end
  end

  xplr.fn.custom.scp.go_to_number = function(app)
    if app.input_buffer and #app.input_buffer ~= 0 then
      state.cursor = tonumber(app.input_buffer)
    end
  end

  xplr.fn.custom.scp.go_up_number = function(app)
    if app.input_buffer and #app.input_buffer ~= 0 then
      state.cursor = math.max(1, state.cursor - tonumber(app.input_buffer))
    end
  end

  xplr.fn.custom.scp.go_down_number = function(app)
    if app.input_buffer and #app.input_buffer ~= 0 then
      state.cursor = math.min(#state.hosts, state.cursor + tonumber(app.input_buffer))
    end
  end

  xplr.fn.custom.scp.go_top = function(_)
    state.cursor = 1
  end

  xplr.fn.custom.scp.go_bottom = function(_)
    state.cursor = #state.hosts
  end

  xplr.fn.custom.scp.toggle_select = function(_)
    local host = state.hosts[state.cursor]
    if state.destinations[state.cursor] then
      state.destinations[state.cursor] = nil
    else
      state.dest_hist_cursor = state.cursor

      return {
        { SwitchModeCustom = "scp_enter_dest" },
        { SetInputPrompt = host .. ":" },
        { SetInputBuffer = "" },
      }
    end
  end

  xplr.fn.custom.scp.toggle_select_all = function(_)
    if count_destinations() == 0 then
      return {
        { SwitchModeCustom = "scp_enter_common_dest" },
        { SetInputPrompt = "*:" },
        { SetInputBuffer = "" },
      }
    else
      state.destinations = {}
    end
  end

  xplr.fn.custom.scp.update_dest = function(app)
    local dest = app.input_buffer or ""
    state.destinations[state.cursor] = dest
    return {
      "PopMode",
    }
  end

  xplr.fn.custom.scp.update_all_dest = function(app)
    local dest = app.input_buffer or ""

    for i, _ in ipairs(state.hosts) do
      state.destinations[i] = dest
    end

    return {
      "PopMode",
    }
  end

  xplr.fn.custom.scp.add_host = function(app)
    if app.input_buffer and #app.input_buffer ~= 0 then
      table.insert(state.hosts, app.input_buffer)
      state.cursor = #state.hosts

      return {
        "PopMode",
        { CallLuaSilently = "custom.scp.toggle_select" },
      }
    else
      return {
        "PopMode",
      }
    end
  end

  xplr.fn.custom.scp.prev_value = function(_)
    if count_destinations() == 0 then
      return
    end

    state.dest_hist_cursor = state.dest_hist_cursor - 1

    while state.destinations[state.dest_hist_cursor] == nil do
      if state.dest_hist_cursor <= 1 then
        state.dest_hist_cursor = #state.hosts + 1
      end
      state.dest_hist_cursor = state.dest_hist_cursor - 1
    end

    return {
      { SetInputBuffer = state.destinations[state.dest_hist_cursor] },
    }
  end

  xplr.fn.custom.scp.next_value = function(_)
    if count_destinations() == 0 then
      return
    end

    state.dest_hist_cursor = state.dest_hist_cursor + 1

    while state.destinations[state.dest_hist_cursor] == nil do
      if state.dest_hist_cursor >= #state.hosts then
        state.dest_hist_cursor = 0
      end
      state.dest_hist_cursor = state.dest_hist_cursor + 1
    end

    return {
      { SetInputBuffer = state.destinations[state.dest_hist_cursor] },
    }
  end

  xplr.fn.custom.scp.send = function(app)
    if #app.selection == 0 then
      return {
        { LogError = "scp: no file selected" },
      }
    end

    if count_destinations() == 0 then
      return {
        { LogError = "no destination selected" },
      }
    end

    for i, dest in pairs(state.destinations) do
      for _, node in ipairs(app.selection) do
        local cmd = args.scp_command
          .. " "
          .. quote(node.absolute_path)
          .. " "
          .. state.hosts[i]
          .. ":"
          .. quote(dest)

        if not args.non_interactive then
          print(cmd)
          io.write("[press ENTER to continue]")
          io.flush()
          _ = io.read()
        end

        os.execute(cmd)
      end
    end

    io.write("[press ENTER to continue]")
    io.flush()
    _ = io.read()

    if not args.keep_selection then
      return {
        "UnSelectAll",
        "PopMode",
      }
    end

    return {
      "PopMode",
    }
  end
end

return { setup = setup }
