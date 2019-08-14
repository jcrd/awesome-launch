# awesome-launch

awesome-launch is a library for [Awesome](https://github.com/awesomeWM/awesome)
window manager that provides functions to spawn clients with single instance
IDs using [wm-launch](https://github.com/jcrd/wm-launch).

## Dependencies

* [uuid](https://luarocks.org/modules/tieske/uuid) rock
* [wm-launch](https://github.com/jcrd/wm-launch)

## Installation

```
$ git clone https://github.com/jcrd/awesome-launch.git
$ cd awesome-launch
$ luarocks make --local
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

## License

awesome-launch is licensed under the GNU General Public License v3.0 or later
(see [LICENSE](LICENSE)).
