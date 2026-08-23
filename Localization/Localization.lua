local _, ns = ...

local L = {}

-- English source text is also the key, so an untranslated entry always has a
-- useful fallback instead of displaying a missing-key marker.
setmetatable(L, {
    __index = function(_, key)
        return key
    end,
})

ns.L = L

