#!/bin/sh
# Turns theme.conf into the settings.js the lock screen imports, since the
# lock screen has no SDDM `config` object. Adds HostName, which SDDM gets
# from sddm.hostName.
#
#   tools/conf2js.sh theme.conf > lockscreen/settings.js
set -eu
conf=${1:?usage: conf2js.sh theme.conf}
host=$(cat /etc/hostname 2>/dev/null || uname -n)

echo ".pragma library"
echo "// Generated from theme.conf by tools/conf2js.sh. Edit theme.conf instead."
echo "var values = {"
awk -F= '
    /^[[:space:]]*(#|;|\[|$)/ { next }
    {
        key = $1
        val = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        gsub(/\\/, "\\\\", val)
        gsub(/"/, "\\\"", val)
        printf "    \"%s\": \"%s\",\n", key, val
    }
' "$conf"
printf '    "HostName": "%s"\n' "$(printf %s "$host" | tr -d '"\\\n')"
echo "};"
