package = "awesome-launch"
version = "0.1.1-1"
source = {
    url = "git://github.com/jcrd/awesome-launch",
    tag = "v0.1.1",
}
description = {
    summary = "AwesomeWM library for launching clients with single instance IDs",
    homepage = "https://github.com/jcrd/awesome-launch",
    license = "GPL-3.0",
}
dependencies = {
    "lua >= 5.1",
    "uuid",
}
build = {
    type = "builtin",
    modules = {
        ["awesome-launch"] = "init.lua",
        ["awesome-launch.panel"] = "panel.lua",
    },
}
