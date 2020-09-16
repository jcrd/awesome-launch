-- This project is licensed under the MIT License (see LICENSE).

--- Widget to show pending clients.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019 James Reed
-- @module awesome-launch.widget

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

local shared = require("awesome-launch.shared")

local widgets = {}

local widget = {}

widget.color = beautiful.bg_focus
widget.border_color = beautiful.fg_normal
widget.width = beautiful.wibar_height or 20
widget.margins = 2

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

local function update_widget(w)
    w.widget:reset()
    for _, data in pairs(shared.pending) do
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

function widget.update_widgets()
    for _, w in ipairs(widgets) do
        update_widget(w)
    end
end

function widget.new(cmd, data)
    local defaults = {
        color = beautiful.bg_focus,
        border_color = beautiful.fg_normal,
        width = 20,
        margins = 2,
    }

    gears.table.crush(defaults, widget)

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

function widget.active()
    return #widgets > 0
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
-- @function launch.widget.launchbar
function widget.launchbar(args)
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

return widget
