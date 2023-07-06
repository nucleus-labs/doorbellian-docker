#!/bin/sh

echo "Doorbellian says hello!"
mount -t proc proc /proc
mount -t sysfs sysfs /sys
ip addr add 10.0.2.15/24 dev eth0
ip link set dev eth0 up
ip route add default via 10.0.2.2 dev eth0
hash -r
/bin/mediamtx /etc/mediamtx.yml
poweroff -f
