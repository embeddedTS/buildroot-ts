#!/bin/sh
if test -z "$XDG_RUNTIME_DIR"; then
    export XDG_RUNTIME_DIR=/run/user/`id -u`
    if ! test -d "$XDG_RUNTIME_DIR"; then
        mkdir --parents $XDG_RUNTIME_DIR
        chmod 0700 $XDG_RUNTIME_DIR
    fi
fi

if [ ! -d "/tmp/.X11-unix" ]; then
    mkdir /tmp/.X11-unix
fi

exec weston --tty 1 --socket wayland-eTS --xwayland
