--- Create new workspaces and launch accompanying clients.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019 James Reed
-- @module awesome-launch.workspace

local awful = require("awful")
local gtable = require("gears.table")
local launch = require("awesome-launch")

local ws = {}
ws.client = {}

function handle_args(tag, args)
    args = args or {}

    if args.pwd then
        tag.pwd = args.pwd
    end

    if args.replace and not tag.volatile then
        for _, c in ipairs(tag:clients()) do c:kill() end
    end

    if args.clients then
        for _, c in ipairs(args.clients) do
            local cmd = c
            local cmdargs
            if type(c) == "table" then
                cmd = c[1]
                cmdargs = gtable.clone(c[2], false)
            end
            ws.client.add(cmd, cmdargs, tag)
        end
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
-- @param args.spawn_callback Function to call with client when it spawns.
-- @param args.factory The factory to use (see wm-launch's -f flag).
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
-- @return The affected tag.
-- @function selected_tag
function ws.selected_tag(args)
    return ws.add(awful.screen.focused().selected_tag, args)
end

return ws
