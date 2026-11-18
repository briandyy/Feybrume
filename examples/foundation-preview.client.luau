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
checked(controls:Caption({ text = "Pick a level and adjust your practice preferences." }))
local tips = checked(controls:Toggle({
    name = "Show training tips", description = "Show guidance before you record a lap.",
    flag = "tips", default = true, persist = true, shared = true,
}))
local hardControl = checked(controls:Checkbox({
    name = "Hard mode reminder", flag = "reminder", persist = true,
    enabledIf = function(flags) return flags.difficulty == "hard" end,
}))
local mode = checked(controls:RadioGroup({
    name = "Difficulty", flag = "difficulty", persist = true, default = "standard",
    options = {
        { id = "easy", name = "Easy" },
        { id = "standard", name = "Standard" },
        { id = "hard", name = "Hard" },
    },
}))
checked(controls:Paragraph({
    text = "Pick a difficulty, then use Record lap to count a practice run.",
    visibleIf = function(flags) return flags.tips == true end,
}))
local laps = checked(controls:Statistic({ name = "Practice count", default = 0, unit = "laps" }))
local status = checked(controls:Label({ text = "Ready" }))
local actions = controls:Grid({ columns = 2, minWidth = 138, rowHeight = 52, gap = 8 })
checked(actions:Button({
    name = "Record lap", variant = "solid",
    onClick = function()
        local count = laps:Get().value + 1
        laps:Set(count)
        status:Set("Lap " .. count .. " recorded on " .. mode:Get().value)
    end,
}))
checked(actions:Button({
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
local labels = audience:HStack({ columns = 2, minWidth = 86, rowHeight = 30, gap = 8 })
checked(labels:Tag({ text = "Practice" }))
checked(labels:Badge({ text = "Guide" }))
checked(audience:RichText({
    text = '<font color="#BBA8FF"><b>Record lap</b></font> counts a run.<br/><i>Load hard preset</i> changes the setup.',
}))
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
tips:OnChanged(function(value, _, source)
    if source == "user" then status:Set(if value then "Training tips on" else "Training tips off") end
end)
hardControl:OnChanged(function(value, _, source)
    if source == "user" then status:Set(if value then "Reminder on" else "Reminder off") end
end)
