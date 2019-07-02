package = "awesome-launch"
version = "0.1.0-1"
source = {
    url = "git://github.com/jcrd/awesome-launch",
    tag = "v0.1.0",
}
description = {
    summary = "AwesomeWM library for launching clients with single instance IDs",
    homepage = "https://github.com/jcrd/awesome-launch",
    license = "GPL-3.0",
}
build = {
    type = "builtin",
    modules = {
        ["awesome-launch"] = "init.lua",
        ["awesome-launch.uuid"] = "uuid.lua",
        ["awesome-launch.panel"] = "panel.lua",
    },
}
