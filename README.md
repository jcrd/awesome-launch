# awesome-launch

awesome-launch is a library for [Awesome](https://github.com/awesomeWM/awesome)
window manager that provides functions to spawn clients with single instance
IDs using [wm-launch](https://github.com/jcrd/wm-launch).

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

See code for additional functions and documentation.

## License

awesome-launch is licensed under the GNU General Public License v3.0 or later
(see [LICENSE](LICENSE)).
