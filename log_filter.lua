-- Filters out rate-limiting-advanced sync-timer debug chatter from error_log.
-- Loaded from init_by_lua_block inside the custom nginx template, so the wrap
-- is installed once at master init and inherited by all workers.

local original_log = ngx.log
local ngx_DEBUG = ngx.DEBUG

original_log(ngx.WARN, "[log_filter] installing ngx.log wrapper at init time")

local DROP_PATTERNS = {
    "%[rate%-limiting%-advanced%] start sync",
    "%[rate%-limiting%-advanced%] empty sync, do fetch",
    "%[rate%-limiting%-advanced%] end sync",
}

local select = select
local tostring = tostring

ngx.log = function(level, ...)
    if level == ngx_DEBUG then
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do
            parts[i] = tostring((select(i, ...)))
        end
        local msg = table.concat(parts, "")
        for i = 1, #DROP_PATTERNS do
            if msg:find(DROP_PATTERNS[i]) then
                return
            end
        end
    end
    return original_log(level, ...)
end
