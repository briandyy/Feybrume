local storage = game:GetService("ReplicatedStorage")
local Fey = require(storage:WaitForChild("Feybrume"))
local workspace = Fey:CreateWorkspace({ theme = "cosmic", flagNamespace = "practice", reopenEdge = "screen" })
local window = workspace:Window({
    id = "practice", title = "Practice kit", width = 640, height = 455,
    reopenBubble = { label = "Kit" },
})

local setup = window:Tab({ id = "setup", title = "Setup" })
local guide = window:Tab({ id = "guide", title = "Guide" })
local controls = setup:Section()
local audience = guide:Section()

local function checked(handle, errorValue)
    assert(handle, errorValue and errorValue.publicMessage or "Could not build control")
    return handle
end

checked(controls:Heading({ text = "Training setup" }))
local mode = checked(controls:RadioGroup({
    name = "Difficulty", flag = "difficulty", persist = true, default = "standard",
    options = {
        { id = "easy", name = "Easy" },
        { id = "standard", name = "Standard" },
        { id = "hard", name = "Hard" },
    },
}))
local tips = checked(controls:Toggle({
    name = "Show training tips", flag = "tips", default = true, persist = true, shared = true,
}))
checked(controls:Paragraph({
    text = "Pick a difficulty, then use Record lap to count a practice run.",
    visibleIf = function(flags) return flags.tips == true end,
}))
local laps = checked(controls:Statistic({ name = "Practice count", default = 0, unit = "laps" }))
local hardControl = checked(controls:Checkbox({
    name = "Hard mode reminder", flag = "reminder", persist = true,
    enabledIf = function(flags) return flags.difficulty == "hard" end,
}))
local status = checked(controls:Label({ text = "Ready" }))
checked(controls:Button({
    name = "Record lap", variant = "solid",
    onClick = function()
        local count = laps:Get().value + 1
        laps:Set(count)
        status:Set("Lap " .. count .. " recorded on " .. mode:Get().value)
    end,
}))
checked(controls:Button({
    name = "Load hard preset", variant = "outline",
    onClick = function()
        local result = workspace:RestoreFlags({ difficulty = "hard", tips = false, reminder = true })
        status:Set(if result.ok then "Hard preset loaded" else result.error.publicMessage)
    end,
}))
checked(controls:Button({
    name = "Reset practice", variant = "ghost",
    onClick = function()
        workspace:RestoreFlags({ difficulty = "standard", tips = true, reminder = false })
        laps:Reset()
        status:Set("Practice reset")
    end,
}))

checked(audience:Subheading({ text = "Quick guide" }))
checked(audience:RichText({ text = "<b>Record lap</b> counts a run. <i>Load hard preset</i> changes the setup." }))
checked(audience:TextDivider({ text = "Shared preferences" }))
checked(audience:Toggle({
    name = "Show training tips", flag = "tips", default = true, persist = true, shared = true,
}))
checked(audience:Caption({ text = "This toggle follows the one on Setup." }))
checked(audience:Quote({ text = "Pick a pace you can repeat.", author = "Practice note" }))
checked(audience:IconText({ text = "Tapping the whole row works on touch." }))
checked(audience:Radio({ name = "Mark guide as read", default = false }))
local theme, switched = "cosmic", "memoir"
checked(audience:IconButton({
    name = "Switch theme", tooltip = "Cycles between Cosmic and Memoir.",
    onClick = function()
        theme, switched = switched, theme
        workspace:SetTheme(theme)
    end,
}))
local labels = audience:Grid({ columns = 2, minWidth = 100, rowHeight = 50 })
checked(labels:Tag({ text = "Practice" }))
checked(labels:Badge({ text = "Guide" }))

tips:OnChanged(function(value, _, source)
    if source == "user" then status:Set(if value then "Training tips on" else "Training tips off") end
end)
hardControl:OnChanged(function(value, _, source)
    if source == "user" then status:Set(if value then "Reminder on" else "Reminder off") end
end)
