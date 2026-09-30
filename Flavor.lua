local addonName, ns = ...

-- World of Warcraft Forever reports WOW_PROJECT_MAINLINE just like retail, so
-- the two clients are told apart by interface version (Forever is 1.x, e.g.
-- 16001; retail is 12.x).
local tocVersion = select(4, GetBuildInfo()) or 0
ns.IsForever = tocVersion < 20000

-- Check these rather than ns.IsForever so gated code keeps working if a
-- client later gains the feature.
ns.Features = {
    FlyingMounts = not ns.IsForever,
    AquaticMounts = not ns.IsForever,
}
