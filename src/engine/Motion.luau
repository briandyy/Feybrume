local Motion = {}
local profiles = {
    instant = { seconds = 0, easing = "Linear", direction = "Out" },
    snappy = { seconds = 0.12, easing = "Quad", direction = "Out" },
    standard = { seconds = 0.18, easing = "Quad", direction = "Out" },
    calm = { seconds = 0.24, easing = "Sine", direction = "Out" },
    slow = { seconds = 0.36, easing = "Sine", direction = "Out" },
    spring = { seconds = 0.26, easing = "Back", direction = "Out" },
    ["optional-drift"] = { seconds = 0.24, easing = "Sine", direction = "Out" },
    ["optional-typewriter"] = { seconds = 0.18, easing = "Quad", direction = "Out" },
}
for _, profile in pairs(profiles) do table.freeze(profile) end

function Motion.HasProfile(profile)
    return profiles[profile] ~= nil
end

function Motion.Resolve(profile, policy)
    policy = policy or {}
    local userSetting = policy.reducedMotion or "system"
    local reduced = userSetting == "always" or (userSetting == "system" and policy.systemReducedMotion == true)
    if reduced then return profiles.instant end
    return profiles[profile] or profiles.standard
end

function Motion.ReadRobloxPreference(services)
    local gui = services:TryGet("GuiService")
    if not gui.ok then return nil end
    local ok, value = pcall(function() return gui.value.ReducedMotionEnabled end)
    if ok and type(value) == "boolean" then return value end
    return nil
end

return table.freeze(Motion)
