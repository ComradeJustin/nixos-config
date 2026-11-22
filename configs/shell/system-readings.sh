#!/bin/sh
# Prints the system readings the monitor shows that have to be read from
# files and commands. MonitorData.qml runs this every two seconds while the
# monitor is open and never otherwise.
#
# The output is sections: a line "== name", then that section's lines.

echo "== processor"
# One line for all cores together, then one per core: time spent in each state.
grep '^cpu' /proc/stat

echo "== memory"
grep -E '^(MemTotal|MemAvailable|Cached|SwapTotal|SwapFree):' /proc/meminfo

echo "== load"
cat /proc/loadavg

echo "== uptime"
cat /proc/uptime

echo "== temperature"
# The hottest sensor, in thousandths of a degree.
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1

echo "== network"
# Bytes received and sent so far, per interface.
grep ':' /proc/net/dev

echo "== storage"
# Size, used and mount point, in kilobytes, one line per file system.
df -P -k / /nix /home /boot 2>/dev/null | tail -n +2 | awk '!seen[$1]++ { print $2, $3, $6 }'

echo "== processes"
# The twelve processes using the most memory: name, kilobytes.
ps -eo comm=,rss= --sort=-rss | head -12

echo "== processCount"
ps -e --no-headers | wc -l

echo "== failed"
systemctl --failed --no-legend --plain 2>/dev/null | awk '{ print $1 }'

echo "== running"
# How many system services are running, then how many of the user's.
systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l
systemctl --user list-units --type=service --state=running --no-legend 2>/dev/null | wc -l

echo "== builders"
# How many processes belong to Nix's build users: more than none means
# something is being built.
ps -eo user= | grep -c '^nixbld'

echo "== generation"
readlink /nix/var/nix/profiles/system

echo "== kernel"
uname -r

echo "== host"
uname -n
