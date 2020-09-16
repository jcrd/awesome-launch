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
local launch = require("awesome-launch")

local ws = {}
ws.client = {}

ws.clients = {}
ws.filename = '.workspace.lua'

function get_filepath(dir)
    if dir:sub(-1) ~= '/' then
        dir = dir..'/'
    end
    return dir..ws.filename
end

function load_workspace(dir)
    local file = get_filepath(dir)
    local f, err = loadfile(file, nil, {workspace=ws.clients})

    if not f then
        naughty.notify {
            preset = naughty.config.presets.critical,
            title = 'Error loading '..file,
            text = err,
        }
        return {}
    end

    local tbl = f()
    local clients = {}

    for _, c in ipairs(tbl) do
        local cmd
        if type(c) == 'table' and type(c[1]) == 'table' then
            c = gtable.clone(c)
            cmd = table.remove(c, 1)
            for _, arg in ipairs(c) do
                cmd[1] = cmd[1]..' '..arg
            end
        end
        table.insert(clients, cmd or c)
    end

    return clients
end

function add_clients(cs, tag)
    for _, c in ipairs(cs) do
        local cmd
        local cmdargs
        if type(c) == "table" then
            cmd = c[1]
            cmdargs = gtable.clone(c[2], false)
        end
        ws.client.add(cmd or c, cmdargs, tag)
    end
end

function handle_args(tag, args)
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

    if args.load_workspace then
        if not args.pwd then
            tag.pwd = args.load_workspace
        end
        add_clients(load_workspace(args.load_workspace), tag)
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
        volatile = true,
    }
    if args and args.props then
        gtable.crush(props, args.props)
    end
    local tag = awful.tag.add(name, props)

    tag:connect_signal("property::selected", function ()
        gtimer.delayed_call(function ()
            if tag.volatile and not tag.selected and #tag:clients() == 0 then
                tag:delete()
            end
        end)
    end)

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

return ws
