# scp.xplr

Integrate xplr with scp

https://user-images.githubusercontent.com/11632726/179600312-845a698d-2c68-4646-9186-00d70ebc9a4f.mp4

## Requirements

- scp

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  local home = os.getenv("HOME")
  package.path = home
    .. "/.config/xplr/plugins/?/init.lua;"
    .. home
    .. "/.config/xplr/plugins/?.lua;"
    .. package.path
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/sayanarijit/scp.xplr ~/.config/xplr/plugins/scp
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("scp").setup()

  -- Or

  require("scp").setup{
    mode = "selection_ops"  -- or `xplr.config.modes.builtin.selection_ops`
    key = "S",
    scp_command = "scp -r",
    non_interactive = false,
    keep_selection = false,
  }

  -- Type `:sS` and send the selected files.
  -- Make sure `~/.ssh/config` or `/etc/ssh/ssh_config` is updated.
  -- Else you'll need to enter each host manually.
  ```

## Features

- Send multiple files to multiple hosts
- Reads ssh config to find predefined hosts
- Toggle select all hosts using `ctrl-a`
- Navigate host list using numbers
