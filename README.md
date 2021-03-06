# awesome-launch

awesome-launch is a library for [Awesome](https://github.com/awesomeWM/awesome)
window manager that provides functions to spawn clients with single instance
IDs using [wm-launch](https://github.com/jcrd/wm-launch).

## Dependencies

* [uuid](https://luarocks.org/modules/tieske/uuid) rock
* [wm-launch](https://github.com/jcrd/wm-launch) >= 0.5.0

## Installation

```
$ git clone https://github.com/jcrd/awesome-launch.git
$ cd awesome-launch
$ luarocks make --local rockspec/awesome-launch-devel-1.rockspec
```

## Usage

Require the library:
```lua
local launch = require("awesome-launch")
```

Now spawn a client:
```lua
launch.spawn("xterm", {id="xterm1"})
```
The new client will have these properties set:
* `single_instance_id` = `"xterm1"`
* `cmdline` = `"xterm"`

See the [API documentation](https://jcrd.github.io/awesome-launch/) for
descriptions of all functions.

## Workspaces

Require the library:
```lua
local ws = require("awesome-launch.workspace")
```

Add a new workspace:
```lua
ws.add("code", {
  pwd = "/home/user/code",
  clients = {
    "xterm -e vim",
    {"qutebrowser", {factory="qutebrowser"}},
  }
})
```

A new tag named `code` will be created with the working directory and clients
listed above.

## Widget

A `launchbar` widget is provided to visualize pending clients.

Customize the launchbar:
```lua
launch.widget.color = beautiful.fg_focus
```

Create a new launchbar for the given screen:
```lua
screen.connect_signal("request::desktop_decoration", function (s)
  ...
  s.launchbar = launch.widget.launchbar {
    screen = s,
  }
  s.mywibox:setup {
    ...
    s.launchbar,
    ...
  }
end)
```

## Command-line client

`awesome-launch` is a wrapper around `awesome-client` that can be used to
launch clients from the command line with single instance IDs tracked by
Awesome.

### Usage

```
usage: awesome-launch [options] COMMAND...

options:
  -h          Show help message
  -s          Launch with systemd-run
  -j          Launch with firejail
  -f FACTORY  Launch via a window factory
  -i ID       The single instance ID to use
  -1          Spawn if not already running
  -r          Raise or spawn
```

Enable use of `awesome-client` by including the following in `rc.lua`:
```lua
require("awful.remote")
```

If installed via `luarocks`, ensure `awesome-launch`'s [location][1] is in your
`PATH`.

[1]: https://github.com/luarocks/luarocks/wiki/File-locations#Path_where_commandline_scripts_are_installed

## License

This project is licensed under the MIT License (see [LICENSE](LICENSE)).
