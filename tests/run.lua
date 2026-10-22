-- Runs the macro text tests. From the addon folder:
--   lua tests/run.lua [filter]
-- Any Lua 5.1+ interpreter works. Only tests whose file or name contains
-- filter are run. Exits with status 1 when a test fails.

local scriptPath = (arg and arg[0]) or "tests/run.lua"
local testDir = scriptPath:gsub("\\", "/"):match("^(.*/)") or "./"
local root = testDir .. "../"

package.path = testDir .. "?.lua;" .. package.path
local T = require("harness")
T.root = root

local TEST_FILES = {
    "macro_core_test",
    "mount_conditionals_test",
    "mount_macro_test",
    "hearthstone_macro_test",
    "fishing_macro_test",
    "outfit_update_macro_test",
    "toy_lines_test",
}

for _, name in ipairs(TEST_FILES) do
    T.SetFile(name)
    dofile(testDir .. name .. ".lua")
end

local filter = arg and arg[1]
local passed, failed, skipped = 0, 0, 0
for _, test in ipairs(T.tests) do
    if filter and not (test.file .. " " .. test.name):find(filter, 1, true) then
        skipped = skipped + 1
    else
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("FAIL " .. test.file .. ": " .. test.name)
            print("     " .. tostring(err):gsub("\n", "\n     "))
        end
    end
end

print(string.format("%d passed, %d failed%s", passed, failed,
    skipped > 0 and (", " .. skipped .. " filtered out") or ""))
if failed > 0 and os.exit then os.exit(1) end
