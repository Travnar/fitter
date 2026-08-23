local addonName, ns = ...

ns.UI_Transmog:RegisterMountPage({
    category = "Flying",
    prefix = "flying",
    ignoreIcon = "Interface\\Icons\\ability_dragonriding_dragonridinggliding01",
    ignoreTooltip = "Use the account-wide flying selection. If none is available, continue to the next applicable mount category.",
    noMountAtlas = "shop-icon-mount-flying-up",
})
