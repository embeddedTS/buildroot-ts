#!/bin/sh

# Add a sleep so that the maximized terminal window doesn't spawn before the panel
sleep 2
/usr/bin/weston-terminal -m --shell /bin/weston-intro.sh
