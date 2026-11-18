local storage = game:GetService("ReplicatedStorage")
local Fey = require(storage:WaitForChild("Feybrume"))
local workspace = Fey:CreateWorkspace({ theme = "cosmic" })
local window = workspace:Window({ id = "workbench", title = "Feybrume Workbench", width = 650, height = 465, reopenLabel = "UI" })

local swatches = { cozy = "memoir", dark = "cosmic", teal = "cultivation" }
local palette = swatches.dark
local paints = {}

local function recolor(node, role, theme)
    node.TextColor3 = Color3.fromHex(theme.tokens.onSurface:sub(2))
    if role == "action" then
        node.BackgroundColor3 = Color3.fromHex(theme.tokens.raised:sub(2))
    end
end

local function paint(node, role, fixedTheme)
    if not paints[node] then node.Destroying:Once(function() paints[node] = nil end) end
    paints[node] = { role = role, theme = fixedTheme }
    recolor(node, role, workspace.Themes:Get(fixedTheme))
end

workspace.Runtime.Scope:Give(workspace.Themes:Subscribe(function(theme)
    for node, item in pairs(paints) do
        if node.Parent then recolor(node, item.role, if item.theme then workspace.Themes:Get(item.theme) else theme) end
    end
end))

local function heading(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 26)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.TextWrapped = true
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 21
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    parent:Add(label)
    paint(label, "heading")
    return label
end

local function paragraph(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text = text
    parent:Add(label)
    paint(label, "body")
    return label
end

local function button(parent, title, callback)
    local object = Instance.new("TextButton")
    object.Size = UDim2.new(1, 0, 0, 48)
    object.Text = title
    object.TextSize = 16
    object.Font = Enum.Font.SourceSansSemibold
    object.TextWrapped = true
    object.BorderSizePixel = 0
    object.Selectable = true
    local shape = Instance.new("UICorner")
    shape.CornerRadius = UDim.new(0, 8)
    shape.Parent = object
    parent:Add(object)
    paint(object, "action")
    object.Activated:Connect(callback)
    return object
end

local function openSheet()
    local sheet = workspace:OpenSheet({ title = "Layout and input", actionLabel = "Done", action = function() end })
    local content = sheet:GetContent()
    paragraph(content, "Resize or rotate the viewport. The action stays fixed while this content scrolls.")
    paragraph(content, "Use Tab or Shift+Tab to move between controls. Press Esc or use Close to go back.")
    button(content, "Open nested sheet", function()
        local nextSheet = workspace:OpenSheet({ title = "Nested sheet", height = 240 })
        paragraph(nextSheet:GetContent(), "Close this sheet to return to the first one.")
    end)
    for i = 1, 5 do paragraph(content, "Scrollable content " .. i) end
    local editor = Instance.new("TextBox")
    editor.Size = UDim2.new(1, -4, 0, 52)
    editor.PlaceholderText = "Try the on-screen keyboard"
    editor.Text = ""
    editor.ClearTextOnFocus = false
    editor.TextSize = 16
    local originalTheme = workspace.Themes:Get()
    editor.BackgroundColor3 = Color3.fromHex(originalTheme.tokens.input:sub(2))
    editor.TextColor3 = Color3.fromHex(originalTheme.tokens.onSurface:sub(2))
    editor.PlaceholderColor3 = Color3.fromHex(originalTheme.tokens.placeholder:sub(2))
    content:Add(editor)
end

local home = window:Tab({ id = "home", title = "Home" })
heading(home, "Window controls")
paragraph(home, "Drag the title to move. Drag the lower-right handle to resize.")
local actions = home:Section({ name = "Actions" }):Grid({ columns = 2, minWidth = 145, rowHeight = 52 })
button(actions, "Open sheet", openSheet)
button(actions, "Dock left", function() window:Dock("left") end)
button(actions, "Dock right", function() window:Dock("right") end)
button(actions, "Floating layout", function() window:Dock("floating") end)

local auxiliary
local function showSecondWindow()
    if auxiliary then
        auxiliary:Show()
        return
    end
    auxiliary = workspace:Window({ id = "secondary", title = "Second Window", theme = "memoir", width = 345, height = 255, reopenLabel = "2" })
    local auxiliaryTab = auxiliary:Tab({ id = "second", title = "Overview" })
    local title = heading(auxiliaryTab, "Second window")
    paint(title, "heading", "memoir")
    local info = paragraph(auxiliaryTab, "This window has its own theme, position, and navigation state.")
    paint(info, "body", "memoir")
end

local preferences = window:Tab({ id = "preferences", title = "Preferences" })
heading(preferences, "Workspace preferences")
local hand = "right"
local settings = preferences:Section():HStack({ columns = 2, minWidth = 145, rowHeight = 52 })
button(settings, "Move bubble to side", function()
    hand = if hand == "left" then "right" else "left"
    workspace:SetReopenSide(hand)
end)
button(settings, "Open second window", showSecondWindow)
button(settings, "Cycle theme", function()
    palette = if palette == swatches.dark then swatches.cozy elseif palette == swatches.cozy then swatches.teal else swatches.dark
    workspace:SetTheme(palette)
end)
button(settings, "Navigation: auto", function() window:SetNavigation("auto") end)
button(settings, "Navigation: top", function() window:SetNavigation("top") end)

local slots = window:Tab({ id = "slots", title = "Slots" })
local demo = slots:Section({ name = "SlotDemonstration" })
heading(demo, "Sections and slots")
paragraph(demo, "Each section can hold leading, main, trailing, footer, background and overlay content.")
local card = Instance.new("Frame")
card.Size = UDim2.new(1, 0, 0, 48)
card.BackgroundColor3 = Color3.fromRGB(50, 68, 108)
card.BorderSizePixel = 0
demo:Add(card, "Footer")

local help = window:Tab({ id = "help", title = "Help" })
heading(help, "Controls")
paragraph(help, "Use Hide in the title bar, then tap the UI bubble to reopen this same tab. Drag the bubble to a free spot.")
local menuTarget = heading(help, "Right-click or touch and hold here")
window:BindContextMenu(menuTarget, {
    { label = "Open sheet", callback = openSheet },
    { label = "Back to Home", callback = function() window:SelectTab("home") end },
}, { title = "Window actions" })
button(help, "Open actions", function()
    window:OpenContextMenu({ { label = "Open sheet", callback = openSheet } }, { title = "Window actions" })
end)
