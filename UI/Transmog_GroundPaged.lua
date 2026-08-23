local addonName, ns = ...

ns.UI_Transmog:RegisterMountPage({
    category = "Ground",
    prefix = "ground",
    ignoreIcon = "Interface\\Icons\\ability_mount_ridinghorse",
    ignoreTooltip = "Use the account-wide ground selection. If none is available, continue to the next applicable mount category.",
    noMountAtlas = "shop-icon-mount-ground-up",
    groundMovementFilters = true,
})
