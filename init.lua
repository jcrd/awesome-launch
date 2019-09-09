--- Launch clients with single instance IDs using wm-launch.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019 James Reed
-- @module awesome-launch

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local uuid = require("uuid")

local shared = require("awesome-launch.shared")

uuid.seed()

local launch = {}
launch.widget = require("awesome-launch.widget")

awesome.register_xproperty("WM_LAUNCH_ID", "string")

awful.rules.add_rule_source("launch",
    function (c, props, callbacks)
        local id = c:get_xproperty("WM_LAUNCH_ID")
        if not id or id == "" then return end

        local data = shared.pending[id]
        if not data then return end

        data.timer:stop()

        gears.table.crush(props, data.props)

        if data.spawn_callback then
            table.insert(callbacks, data.spawn_callback)
        end

        shared.pending[id] = nil
        launch.widget.update_widgets()
    end)

awful.client.property.persist("cmdline", "string")

launch.client = {}

local function get_ids()
    local ids = {}
    for _, c in ipairs(client.get()) do
        if c.single_instance_id then ids[c.single_instance_id] = c end
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
-- @param args.spawn_callback Function to call with client when it spawns.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.firejail If true, run cmd with firejail.
-- @return The client's ID.
-- @function launch.spawn
local function spawn(cmd, args)
    args = args or {}
    local id = args.id or uuid()
    local data = {
        props = args.props or {},
        pwd = args.pwd,
        spawn_callback = args.spawn_callback,
        timeout = math.ceil(args.timeout or 10),
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
        launch_cmd = launch_cmd .. " -f " .. args.factory
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
-- @param args.spawn_callback Function to call with client when it spawns.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.firejail If true, run cmd with firejail.
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
    if not c then return spawn(cmd, args) end
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
-- @param args.spawn_callback Function to call with client when it spawns.
-- @param args.callback Function to call with client when it spawns or is raised.
-- @param args.factory The factory to use (see wm-launch's -f flag).
-- @param args.firejail If true, run cmd with firejail.
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
            {raise=true})
        if args.callback then
            args.callback(c)
        end
        return args.id
    end
    if args.callback then
        local cb = args.spawn_callback
        args.spawn_callback = function (c)
            if cb then cb(c) end
            args.callback(c)
        end
    end
    return spawn(cmd, args)
end

return launch
