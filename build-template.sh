#!/bin/sh
# Builds a custom nginx template by inlining the bundled nginx_kong.lua body
# into nginx.lua (replacing the `include 'nginx-kong.conf';` line) and
# injecting a dofile() call at the top of the init_by_lua_block so our
# log filter wrapper is installed before Kong.init() runs.
set -eu

NGINX_TPL=/usr/local/share/lua/5.1/kong/templates/nginx.lua
KONG_TPL=/usr/local/share/lua/5.1/kong/templates/nginx_kong.lua
OUT=/etc/kong/custom_nginx.template

test -f "$NGINX_TPL" || { echo "missing $NGINX_TPL" >&2; exit 1; }
test -f "$KONG_TPL"  || { echo "missing $KONG_TPL"  >&2; exit 1; }

tmp=$(mktemp)

# The bundled templates are Lua files that `return [[ ...template... ]]`.
# Strip the Lua wrapping so what remains is the raw Penlight/nginx body
# that --nginx-conf expects.
strip_lua_wrap() {
    # Removes lines before `return [[` (inclusive) and from `]]` (inclusive) onward.
    awk '
        BEGIN { body = 0 }
        !body && /^return[[:space:]]*\[\[/ { body = 1; next }
        body && /^\]\][[:space:]]*$/        { exit }
        body { print }
    ' "$1"
}

nginx_body=$(strip_lua_wrap "$NGINX_TPL")
kong_body=$(strip_lua_wrap "$KONG_TPL")

# Inline nginx_kong.lua body at the `include 'nginx-kong.conf';` site.
printf '%s\n' "$nginx_body" | awk -v kong_body="$kong_body" '
    /include[[:space:]]+.?nginx-kong\.conf.?;/ {
        print kong_body
        next
    }
    { print }
' > "$tmp"

# Inject our dofile at the top of the init_by_lua_block so ngx.log is
# wrapped before Kong.init() runs. Uses # as sed delimiter to avoid
# escaping the slashes in the path.
sed -i "/init_by_lua_block[[:space:]]*{/a\\
    dofile('/etc/kong/log_filter.lua')
" "$tmp"

install -m 0644 "$tmp" "$OUT"
rm -f "$tmp"

echo "wrote $OUT"
grep -n "dofile('/etc/kong/log_filter.lua')" "$OUT" || {
    echo "ERROR: dofile() not injected; check nginx_kong.lua layout" >&2
    exit 1
}
