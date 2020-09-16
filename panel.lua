-- This project is licensed under the MIT License (see LICENSE).

--- Launch clients as panels.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019-2020 James Reed
-- @module awesome-launch.panel

local awful = require("awful")
local gtable = require("gears.table")
local launch = require("awesome-launch")

local panel = {}

-- TODO: Reapply args on restart with rule source.
-- See: https://github.com/awesomeWM/awesome/issues/2725
local function spawn(cmd, args)
    local cb = args.callback
    args.callback = function (c)
        c.hidden = true
        c.sticky = true
        c.floating = true
        c.skip_taskbar = true
        awful.placement.scale(c, {to_percent=args.scale or 0.5})
        awful.placement.centered(c)
        c:connect_signal("unfocus", function () c.hidden = true end)
        if cb then cb(c) end
    end
    launch.spawn.single_instance(cmd, args)
end

local function toggle(c)
    if c == client.focus then
        c.hidden = true
    else
        c.hidden = false
        c:emit_signal("request::activate", "panel.toggle", {raise=true})
    end
end

--- Toggle the visibility of a panel, spawning the command if necessary.
--
-- A panel is a floating, centered client that can be scaled to a percentage of
-- its size.
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
-- @param args.filter Function to filter clients that are considered.
-- @param args.scale Percent to scale client (see awful.placement.scale).
-- @function panel.toggle
function panel.toggle(cmd, args)
    local c = launch.client.by_id(args.id)
    if c then
        toggle(c)
    else
        local a = {callback = function (c) toggle(c) end}
        gtable.crush(a, args)
        spawn(cmd, a)
    end
end

return panel
