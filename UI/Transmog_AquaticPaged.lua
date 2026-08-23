local addonName, ns = ...

ns.UI_Transmog:RegisterMountPage({
    category = "Aquatic",
    prefix = "aquatic",
    ignoreIcon = "Interface\\Icons\\item_aquaticfin_17",
    ignoreTooltip = "Use the account-wide aquatic selection. If none is configured, resolve the flying outfit or account-wide selection in flyable areas, then use the outfit's ground mount.",
    noMountAtlas = "shop-icon-mount-aquatic-up",
})
