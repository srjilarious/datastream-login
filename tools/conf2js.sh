#!/bin/sh
# Turns theme.conf into the settings.js the lock screen imports, since the
# lock screen has no SDDM `config` object. Adds HostName, which SDDM gets
# from sddm.hostName.
#
# Takes one or more .conf files; a key in a later file overrides the same
# key in an earlier one. Missing files after the first are skipped, so the
# settings app's saved choices can be passed whether or not they exist yet.
#
#   tools/conf2js.sh theme.conf [~/.config/datastream/settings.conf] > settings.js
set -eu
[ $# -ge 1 ] || { echo "usage: conf2js.sh theme.conf [override.conf...]" >&2; exit 2; }
host=$(cat /etc/hostname 2>/dev/null || uname -n)

files=$1
shift
for f in "$@"; do
    [ -f "$f" ] && files="$files
$f"
done

echo ".pragma library"
echo "// Generated from theme.conf by tools/conf2js.sh. Edit theme.conf instead."
echo "var values = {"
# Split on newlines only, so paths with spaces survive.
old_ifs=$IFS
IFS='
'
# shellcheck disable=SC2086
awk '
    /^[[:space:]]*(#|;|\[|$)/ { next }
    {
        key = substr($0, 1, index($0, "=") - 1)
        val = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        if (key == "") next
        gsub(/\\/, "\\\\", val)
        gsub(/"/, "\\\"", val)
        if (!(key in values))
            order[n++] = key
        values[key] = val
    }
    END {
        for (i = 0; i < n; i++)
            printf "    \"%s\": \"%s\",\n", order[i], values[order[i]]
    }
' $files
IFS=$old_ifs
printf '    "HostName": "%s"\n' "$(printf %s "$host" | tr -d '"\\\n')"
echo "};"
