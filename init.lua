-- This project is licensed under the MIT License (see LICENSE).

--- Launch clients with single instance IDs using wm-launch.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019-2020 James Reed
-- @module awesome-launch

local awful = require("awful")
local gears = require("gears")
local ruled = require("ruled")
local wibox = require("wibox")
local beautiful = require("beautiful")
local uuid = require("uuid")

local shared = require("awesome-launch.shared")

uuid.seed()

local launch = {}
launch.widget = require("awesome-launch.widget")

awesome.register_xproperty("WM_LAUNCH_ID", "string")

local function get_data(c)
    local id = c:get_xproperty("WM_LAUNCH_ID")
    if id and id ~= "" then
        return shared.pending[id]
    end
    for _, data in pairs(shared.pending) do
        if data.rule and ruled.client.match(c, data.rule) then
            return data
        end
    end
end

awful.rules.add_rule_source("launch",
    function (c, props, callbacks)
        local data = get_data(c)
        if not data then
            return
        end

        data.timer:stop()

        if data.props.tag and not data.props.tag.activated then
            data.props.tag = awful.screen.focused().selected_tag
        end

        gears.table.crush(props, data.props)

        if data.callback then
            table.insert(callbacks, data.callback)
        end

        if data.factory then
            c:connect_signal("request::unmanage", function ()
                awful.spawn("wm-launchd -check " .. data.factory)
            end)
        end

        shared.pending[data.id] = nil
        launch.widget.update_widgets()
    end)

awful.client.property.persist("cmdline", "string")

launch.client = {}

local function get_ids()
    local ids = {}
    for _, c in ipairs(client.get()) do
        if c.single_instance_id then
            ids[c.single_instance_id] = c
        end
    end
    return ids
end

--- Get a launched client by its ID.
--
-- @param id The ID.
-- @param filter Function to filter clients that are considered.
-- @return The client.
-- @function client.by_id
function launch.client.by_id(id, filter)
    for _, c in ipairs(client.get()) do
        if (not filter or filter(c)) and c.single_instance_id == id then
            return c
        end
    end
end

--- Get a launched client by its command line.
--
-- @param cmd The command line.
-- @param filter Function to filter clients that are considered.
-- @return The client.
-- @function client.by_cmdline
function launch.client.by_cmdline(cmd, filter)
    for _, c in ipairs(client.get()) do
        if (not filter or filter(c)) and c.cmdline == cmd then
            return c
        end
    end
end

--- Spawn a client with wm-launch.
--
-- @param cmd The command.
-- @param args Table containing the single instance ID and additional arguments
-- @param args.id Single instance ID.
-- @param args.props Properties to apply to the client.
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.timeout Seconds after which to stop waiting for a client to spawn.
-- @param args.callback Function to call with client when it spawns.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.systemd If true, run cmd with systemd-run.
-- @param args.firejail If true, run cmd with firejail.
-- @param args.rule Fallback client rule used if setting the ID fails.
-- @return The client's ID.
-- @function launch.spawn
local function spawn(cmd, args)
    args = args or {}
    local id = args.id or uuid()
    local data = {
        id = id,
        props = args.props or {},
        pwd = args.pwd,
        callback = args.callback,
        timeout = math.ceil(args.timeout or 10),
        rule = args.rule,
    }

    gears.table.crush(data.props, {
        single_instance_id = id,
        cmdline = cmd,
    })

    local step = 1/2
    data.timer = gears.timer {
        timeout = step,
        callback = function ()
            data.timeout = data.timeout - step
            if data.timeout == 0 then
                shared.pending[id] = nil
                launch.widget.update_widgets()
                return false
            else
                data.widget.id_const.id_margin.id_progress.value = data.timeout
            end
            return true
        end,
    }

    if launch.widget.active() then
        data.widget = launch.widget.new(cmd, data)
    end

    local launch_cmd = "wm-launch"

    if args.factory then
        data.factory = args.factory
        launch_cmd = launch_cmd .. " -f " .. args.factory
    end

    if args.systemd then
        launch_cmd = launch_cmd .. " -s"
    end

    if args.firejail then
        launch_cmd = launch_cmd .. " -j"
    end

    launch_cmd = string.format("%s %s %s", launch_cmd, id, cmd)

    if data.pwd then
        awful.spawn.with_shell(string.format("cd %s; %s", data.pwd, launch_cmd))
    else
        awful.spawn(launch_cmd)
    end

    shared.pending[id] = data
    launch.widget.update_widgets()
    data.timer:start()

    return id
end

launch.spawn = {}

setmetatable(launch.spawn, {__call = function (_, ...) spawn(...) end})

--- Spawn a command if an instance is not already running.
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
-- @param args.rule Fallback client rule used if setting the ID fails.
-- @param args.filter Function to filter clients that are considered.
-- @return The client's ID.
-- @function spawn.single_instance
function launch.spawn.single_instance(cmd, args)
    local c
    if args.id then
        c = launch.client.by_id(args.id, args.filter)
    else
        c = launch.client.by_cmdline(cmd, args.filter)
    end
    if not c then
        return spawn(cmd, args)
    end
    return args.id
end

--- Raise a client if it exists or spawn a new one then raise it.
--
-- @param cmd The command.
-- @param args Table containing the single instance ID and additional arguments for spawn
-- @param args.id Single instance ID.
-- @param args.props Properties to apply to the client.
-- @param args.pwd Pathname to the working directory for new clients.
-- @param args.timeout Seconds after which to stop waiting for a client to spawn.
-- @param args.callback Function to call with client when it spawns.
-- @param args.raise_callback Function to call with client when it spawns or is raised.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.systemd If true, run cmd with systemd-run.
-- @param args.firejail If true, run cmd with firejail.
-- @param args.rule Fallback client rule used if setting the ID fails.
-- @param args.filter Function to filter clients that are considered.
-- @return The client's ID.
-- @function spawn.raise_or_spawn
function launch.spawn.raise_or_spawn(cmd, args)
    local c
    if args.id then
        c = launch.client.by_id(args.id, args.filter)
    else
        c = launch.client.by_cmdline(cmd, args.filter)
    end
    if c then
        c:emit_signal("request::activate", "launch.spawn.raise_or_spawn",
            {raise = true})
        if args.raise_callback then
            args.raise_callback(c)
        end
        return args.id
    end
    if args.raise_callback then
        local cb = args.callback
        args.callback = function (c)
            if cb then
                cb(c)
            end
            args.raise_callback(c)
        end
    end
    return spawn(cmd, args)
end

--- Spawn clients on a tag.
--
-- Usage: `launch.spawn.here().spawn("xterm")`
--
-- @param tag_func Optional function that returns the tag, defaults to
-- `awful.screen.focused().selected_tag`.
-- @return A table with the functions: spawn, single_instance, raise_or_spawn.
-- @function spawn.here
function launch.spawn.here(tag_func)
    local here = {}

    local function with_tag(func, cmd, args)
        local tag
        if tag_func then
            tag = tag_func()
        else
            tag = awful.screen.focused().selected_tag
        end

        local a = {
            filter = function (c)
                return c:isvisible()
            end,
            props = {tag = tag},
        }
        gears.table.crush(a, args or {})
        func(cmd, a)
    end

    function here.spawn(...)
        with_tag(launch.spawn, ...)
    end

    function here.single_instance(...)
        with_tag(launch.spawn.single_instance, ...)
    end

    function here.raise_or_spawn(...)
        with_tag(launch.spawn.raise_or_spawn, ...)
    end

    return here
end

return launch
