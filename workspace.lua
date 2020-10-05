-- This project is licensed under the MIT License (see LICENSE).

--- Create new workspaces and launch accompanying clients.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019-2020 James Reed
-- @module awesome-launch.workspace

local awful = require("awful")
local naughty = require("naughty")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local protected_call = require("gears.protected_call")
local launch = require("awesome-launch")

local lgi = require("lgi")
local Gio, GLib, GObject = lgi.Gio, lgi.GLib, lgi.GObject

local ws = {}
ws.client = {}

ws.clients = {}

local function add_clients(cs, tag)
    for _, c in ipairs(cs) do
        local cmd
        local cmdargs
        if type(c) == "table" then
            cmd = c[1]
            if c[2] then
                cmdargs = gtable.clone(c[2], false)
            end
        end
        ws.client.add(cmd or c, cmdargs, tag)
    end
end

local function handle_args(tag, args)
    args = args or {}

    if args.pwd then
        tag.pwd = args.pwd
    end

    if args.replace and not tag.volatile then
        for _, c in ipairs(tag:clients()) do c:kill() end
    end

    if args.clients then
        add_clients(args.clients, tag)
    end

    if args.callback then
        args.callback(tag)
    end

    return tag
end

--- Spawn a command and add the client to a tag.
--
-- @param cmd The command.
-- @param args Table containing the single instance ID and additional arguments for spawn
-- @param args.id Single instance ID.
-- @param args.props Properties to apply to the client.
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.timeout Seconds after which to stop waiting for a client to spawn.
-- @param args.callback Function to call with client when it spawns.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.systemd If true, run cmd with systemd-run.
-- @param args.firejail If true, run cmd with firejail.
-- @param tag The tag.
-- @function client.add
function ws.client.add(cmd, args, tag)
    args = args and gtable.clone(args) or {}
    tag = tag or awful.screen.focused().selected_tag
    args.props = args.props or {}
    args.props.tag = tag
    args.props.tags = nil
    if tag.pwd then
        args.pwd = tag.pwd
    end
    launch.spawn(cmd, args)
end

--- Create a new workspace and underlying (volatile) tag.
--
-- @param name The tag name.
-- @param args Table containing tag properties and additional workspace options
-- @param args.props Properties to apply to the tag.
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.clients Table containing client commands to spawn.
--
-- Example: `args.clients = { "xterm",
-- {"qutebrowser", {factory="qutebrowser"}} }`
--
-- @param args.load_workspace Path to directory containing workspace file to
-- load. Implies args.pwd.
-- @param args.callback Function to call with newly created tag.
-- @return The new tag.
-- @function new
function ws.new(name, args)
    local props = {
        screen = awful.screen.focused(),
        layout = awful.layout.layouts[1],
    }
    if args and args.props then
        gtable.crush(props, args.props)
    end
    local tag = awful.tag.add(name, props)

    local function delete()
        gtimer.delayed_call(function ()
            if not tag.selected and #tag:clients() == 0 then
                tag:delete()
            end
        end)
    end

    tag:connect_signal("property::selected", delete)
    tag:connect_signal("untagged", delete)

    return handle_args(tag, args)
end

--- Add to or replace a given tag's clients.
--
-- @param tag The tag to affect.
-- @param args Table containing tag properties and additional workspace options
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.replace Kill tag's existing clients if true.
-- @param args.clients Table containing client commands to spawn.
--
-- Example: `args.clients = { "xterm",
-- {"qutebrowser", {factory="qutebrowser"}} }`
--
-- @param args.load_workspace Path to directory containing workspace file to
-- load. Implies args.pwd.
-- @return The affected tag.
-- @function add
function ws.add(tag, args)
    return handle_args(tag, args)
end

--- Add to or replace the selected tag's clients.
--
-- @param args Table containing tag properties and additional workspace options
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.replace Kill tag's existing clients if true.
-- @param args.clients Table containing client commands to spawn.
--
-- Example: `args.clients = { "xterm",
-- {"qutebrowser", {factory="qutebrowser"}} }`
--
-- @param args.load_workspace Path to directory containing workspace file to
-- load. Implies args.pwd.
-- @return The affected tag.
-- @function selected_tag
function ws.selected_tag(args)
    return ws.add(awful.screen.focused().selected_tag, args)
end

local methods = {}

local function parse_client(s)
    local c = {}
    local i = 1
    for t in string.gmatch(s, '[^%s]+') do
        if i == 1 then
            if t:sub(1, 1) == '@' then
                local n = t:sub(2)
                c = ws.clients[n]
                if not c then
                    naughty.notify {
                        preset = naughty.config.presets.critical,
                        title = 'Client not defined',
                        text = n,
                    }
                    return
                end
            else
                c[1] = t
            end
        else
            c[1] = string.format('%s %s', c[1], t)
        end
        i = i + 1
    end
    return c
end

function methods.Workspace(params, i)
    local args = {
        clients = {},
        callback = function (t)
            t:view_only()
        end,
    }

    if params.value[2] ~= '' then
        args.pwd = params.value[2]
    end

    for _, s in params:get_child_value(3 - 1):ipairs() do
        local c = parse_client(s)
        if c then
            table.insert(args.clients, c)
        end
    end

    ws.new(params.value[1], args)

    i:return_value(GLib.Variant('()'))
end

local function method_call(_, _, _, _, method, params, invocation)
    if methods[method] then
        protected_call(methods[method], params, invocation)
    end
end

local function on_bus_acquired(conn, _)
    local function arg(name, sig)
        return Gio.DBusArgInfo {
            name = name,
            signature = sig,
        }
    end
    local method = Gio.DBusMethodInfo

    local iface = Gio.DBusInterfaceInfo {
        name = 'com.github.jcrd.wm_launch.WindowManager',
        methods = {
            method {
                name = 'Workspace',
                in_args = {
                    arg('name', 's'),
                    arg('pwd', 's'),
                    arg('clients', 'as'),
                },
            },
        },
    }

    conn:register_object('/com/github/jcrd/wm_launch/WindowManager',
        iface,
        GObject.Closure(method_call))
end

Gio.bus_own_name(Gio.BusType.SESSION,
    'com.github.jcrd.wm_launch',
    Gio.BusNameOwnerFlags.NONE,
    GObject.Closure(on_bus_acquired))

return ws
