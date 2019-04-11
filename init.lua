--- Launch clients with single instance IDs using wm-launch.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019 James Reed
-- @module launch

local awful = require("awful")
local gears = require("gears")

local pending = {}

awesome.register_xproperty("WM_LAUNCH_ID", "string")

awful.rules.add_rule_source("launch",
    function (c, props, callbacks)
        local id = c:get_xproperty("WM_LAUNCH_ID")
        if not id or id == "" then return end

        local data = pending[id]
        if not data then return end

        data.timer:stop()

        gears.table.crush(props, data.props)

        if data.callback then
            table.insert(callbacks, data.callback)
        end

        pending[id] = nil
    end)

awful.client.property.persist("cmdline", "string")

local launch = {}
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

local function gen_id()
    local i = 1
    local id = "1"
    local ids = get_ids()
    while ids[id] do
        i = i + 1
        id = string.format("%d", i)
    end
    return id
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
-- @return The client's ID.
-- @function launch.spawn
local function spawn(cmd, args)
    args = args or {}
    id = args.id or gen_id()
    local data = {
        props = args.props or {},
        tags = args.tags,
        pwd = args.pwd,
        callback = args.callback,
    }

    gears.table.crush(data.props, {
            single_instance_id = id,
            cmdline = cmd,
        })

    data.timer = gears.timer {
        timeout = args.timeout or 10,
        single_shot = true,
        callback = function () pending[id] = nil end,
    }

    local launch = string.format("wm-launch %s %s", id, cmd)

    if data.pwd then
        awful.spawn.with_shell(string.format("cd %s; %s", data.pwd, launch))
    else
        awful.spawn(launch)
    end

    pending[id] = data
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
-- @param args.callback Function to call with client when it spawns.
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
        return args.id
    end
    return spawn(cmd, args)
end

return launch
