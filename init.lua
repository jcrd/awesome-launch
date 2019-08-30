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

uuid.seed()

local pending = {}
local widgets = {}

local launch = {}
launch.widget = {}

launch.widget.color = beautiful.bg_focus
launch.widget.border_color = beautiful.fg_normal
launch.widget.width = beautiful.wibar_height or 20
launch.widget.margins = 2

local function props_visible(s, p)
    if p.screen and p.screen ~= s then
        return false
    end
    local function selected(t)
        if gears.table.hasitem(s.selected_tags, t) then
            return true
        end
    end
    if p.first_tag then
        return selected(p.first_tag)
    end
    if p.tag then
        return selected(p.tag)
    end
    if p.tags then
        for _, t in ipairs(p.tags) do
            if selected(t) then return true end
        end
    end
end

local function new_widget(cmd, data, theme)
    local defaults = {
        color = beautiful.bg_focus,
        border_color = beautiful.fg_normal,
        width = 20,
        margins = 2,
    }

    gears.table.crush(defaults, theme)

    return wibox.widget {
        {
            {
                {
                    id = "id_progress",
                    min_value = 0,
                    max_value = data.timeout,
                    value = data.timeout,
                    color = defaults.color,
                    border_color = defaults.border_color,
                    widget = wibox.container.radialprogressbar,
                },
                id = "id_margin",
                margins = defaults.margins,
                layout = wibox.container.margin,
            },
            id = "id_const",
            width = defaults.width,
            layout = wibox.container.constraint,
        },
        {
            text = cmd,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.horizontal,
    }
end

local function update_widget(w)
    w.widget:reset()
    for _, data in pairs(pending) do
        local visible = true
        if w.only_tagged then
            visible = props_visible(w.screen or awful.screen.focused(),
                data.props)
        end
        if visible and (not w.filter or w.filter(data)) then
            w.widget:add(data.widget)
        end
    end
end

local function update_widgets()
    for _, w in ipairs(widgets) do
        update_widget(w)
    end
end

--- Create a new launchbar widget.
--
-- The following options are available to customize the widget's
-- radialprogressbar:
--
--   launch.widget.color
--
--   launch.widget.border_color
--
--   launch.widget.width
--
--   launch.widget.margins
--
-- @param args Table containing widget options
-- @param args.screen The screen pending clients must belong to.
-- @param args.filter Function to filter clients that are considered.
-- @param args.only_tagged Show only pending clients with selected tags.
-- @return The widget.
-- @function widget.launchbar
function launch.widget.launchbar(args)
    args = args or {}
    local w = {
        screen = args.screen,
        filter = args.filter,
        only_tagged = true,
        widget = wibox.widget {
            layout = wibox.layout.fixed.horizontal,
        },
    }

    if args.only_tagged == false then
        w.only_tagged = false
    end

    if w.only_tagged and w.screen then
        screen.connect_signal("tag::history::update", function (s)
            if s == w.screen then
                update_widget(w)
            end
        end)
    end

    table.insert(widgets, w)

    return w.widget
end


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
        update_widgets()
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
-- @param args.callback Function to call with client when it spawns.
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
        callback = args.callback,
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
                pending[id] = nil
                update_widgets()
                return false
            else
                data.widget.id_const.id_margin.id_progress.value = data.timeout
            end
            return true
        end,
    }

    if #widgets > 0 then
        data.widget = new_widget(cmd, data, launch.widget)
    end

    local launch = "wm-launch"

    if args.factory then
        launch = launch .. " -f " .. args.factory
    end

    if args.firejail then
        launch = launch .. " -j"
    end

    launch = string.format("%s %s %s", launch, id, cmd)

    if data.pwd then
        awful.spawn.with_shell(string.format("cd %s; %s", data.pwd, launch))
    else
        awful.spawn(launch)
    end

    pending[id] = data
    update_widgets()
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
-- @param args.callback Function to call with client when it spawns.
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
        return args.id
    end
    return spawn(cmd, args)
end

return launch
