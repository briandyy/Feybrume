local Layout = require("../src/engine/Layout")
local Gesture = require("../src/engine/Gesture")
local Focus = require("../src/engine/Focus")
local Factory = require("../src/engine/Factory")

local count = 0
local limits = { minWidth = 280, minHeight = 220, maxWidth = 1200, maxHeight = 900 }

local function test(name, run)
    local ok, err = xpcall(run, debug.traceback)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    count += 1
    print("PASS " .. name)
end

local function equal(actual, expected)
    assert(actual == expected, string.format("Expected %s, received %s", tostring(expected), tostring(actual)))
end

local function contained(rect, area)
    assert(rect.x >= area.x and rect.y >= area.y)
    assert(rect.x + rect.width <= area.x + area.width)
    assert(rect.y + rect.height <= area.y + area.height)
end

test("mobile and desktop breakpoints honor width, height, and input separately", function()
    local cases = {
        { 320, 568, "touch", "micro", "bottom" },
        { 360, 640, "touch", "compact", "bottom" },
        { 393, 870, "touch", "compact", "bottom" },
        { 430, 932, "touch", "compact", "bottom" },
        { 640, 360, "touch", "phoneLarge", "drawer" },
        { 740, 360, "touch", "tablet", "drawer" },
        { 870, 393, "gamepad", "tablet", "drawer" },
        { 768, 1024, "touch", "tablet", "left" },
        { 1280, 720, "pointer", "desktop", "left" },
    }
    for _, record in ipairs(cases) do
        local profile = Layout.Profile(record[1], record[2], record[3])
        equal(profile.name, record[4])
        equal(profile.navigation, record[5])
        equal(profile.touch, record[3] == "touch")
    end
end)

test("breakpoints reject invalid order and allow overrides", function()
    local custom = Layout.ValidateBreakpoints({ phone = 760, short = 450 })
    equal(Layout.Profile(720, 500, "touch", custom).navigation, "bottom")
    equal(Layout.Profile(720, 430, "touch", custom).navigation, "drawer")
    equal(pcall(Layout.ValidateBreakpoints, { tablet = 500 }), false)
    equal(pcall(Layout.ValidateBreakpoints, { typo = 800 }), false)
end)

test("clamping fits a rectangle smaller than the configured minimum", function()
    local area = Layout.Rect(8, 8, 230, 158)
    local rect = Layout.Clamp(Layout.Rect(-30, 190, 200, 170), area, 280, 220)
    contained(rect, area)
    equal(rect.width, 230)
    equal(rect.height, 158)
end)

test("chrome fits full labels and refreshes cached widths when the label or text scale changes", function()
    local calls, multiplier = 0, 1
    local button = { Text = "Max", TextSize = 14, Font = "SourceSans" }
    local function measure(text, size, font)
        calls += 1
        assert(font == button.Font)
        return #text * size * 0.6 * multiplier
    end
    equal(Factory.ButtonWidth(button, measure, "medium", 52), 52)
    button.Text = "Restore"
    equal(Factory.ButtonWidth(button, measure, "medium", 52), 75)
    equal(Factory.ButtonWidth(button, measure, "medium", 52), 75)
    equal(calls, 2)
    button.TextSize = 20
    equal(Factory.ButtonWidth(button, measure, "medium", 52), 100)
    multiplier = 1.25
    equal(Factory.ButtonWidth(button, measure, "largest", 52), 121)
    button.Font = "BuilderSans"
    equal(Factory.ButtonWidth(button, measure, "largest", 52), 121)
    equal(calls, 5)
end)

test("compact layout keeps the original floating request for restoration", function()
    local desktop = Layout.Rect(8, 8, 1200, 700)
    local mobile = Layout.Rect(8, 8, 344, 620)
    local pointer = Layout.Profile(1216, 716, "pointer")
    local touch = Layout.Profile(360, 636, "touch")
    local original = Layout.Rect(180, 145, 605, 449)
    equal(Layout.Window(original, mobile, touch, "floating", limits, true).width, mobile.width)
    local restored = Layout.Window(original, desktop, pointer, "floating", limits, true)
    equal(restored.x, 180)
    equal(restored.width, 605)
    local compactFloating = Layout.Window(original, mobile, touch, "floating", limits, false)
    contained(compactFloating, mobile)
end)

test("left and right docking never overlaps at supported widths", function()
    local area = Layout.Rect(8, 8, 1230, 630)
    local profile = Layout.Profile(area.width, area.height, "pointer")
    local before = Layout.Center(area, 500, 410)
    local left = Layout.Window(before, area, profile, "left", limits, true)
    local right = Layout.Window(before, area, profile, "right", limits, true)
    contained(left, area)
    contained(right, area)
    equal(Layout.Intersects(left, right), false)
    equal(left.width, right.width)
    equal(right.x - left.x - left.width, 8)
end)

test("resize preserves the loaded origin and obeys min max and safe area", function()
    local area = Layout.Rect(0, 0, 1000, 640)
    local rect = Layout.Rect(180, 120, 620, 400)
    local small = Layout.Resize(rect, area, -999, -999, limits)
    equal(small.width, limits.minWidth)
    equal(small.height, limits.minHeight)
    local large = Layout.Resize(rect, area, 999, 999, limits)
    equal(large.x, rect.x)
    equal(large.y, rect.y)
    equal(large.width, 820)
    equal(large.height, 520)
    contained(large, area)
end)

test("edge targets distinguish left right top and free drop", function()
    local area = Layout.Rect(8, 8, 800, 600)
    equal(Layout.DockAt(12, 300, area, 22), "left")
    equal(Layout.DockAt(792, 300, area, 22), "right")
    equal(Layout.DockAt(17, 20, area, 22), "fullscreen")
    equal(Layout.DockAt(400, 150, area, 22), "floating")
end)

test("keyboard contraction leaves an undocked window and sheet reachable", function()
    local base = Layout.Rect(0, 0, 393, 820)
    local keyboard = Layout.Rect(0, 494, 393, 326)
    local area = Layout.Inset(Layout.KeyboardArea(base, keyboard), 8)
    local profile = Layout.Profile(393, 820, "touch")
    local sheet = Layout.Sheet(area, profile, 460, 390)
    local window = Layout.Window(Layout.Rect(0, 0, 550, 540), area, profile, "floating", limits, true)
    contained(sheet, area)
    contained(window, area)
    equal(sheet.width, area.width)
    equal(sheet.y + sheet.height, area.y + area.height)
    equal(area.height, 478)
end)

test("landscape sheet centers instead of covering the full bottom row", function()
    local area = Layout.Rect(8, 8, 624, 320)
    local sheet = Layout.Sheet(area, Layout.Profile(640, 360, "touch"), 460, 390)
    equal(sheet.x, 90)
    equal(sheet.y, area.y)
    equal(sheet.width, 460)
    contained(sheet, area)
end)

test("floating bubble stays clear of movement and neighboring bubbles", function()
    local area = Layout.Rect(8, 8, 344, 620)
    local reserved = { Layout.Rect(214, 486, 138, 142), Layout.Rect(8, 486, 138, 142) }
    local first = assert(Layout.Bubble(area, reserved, "right", 594, 52))
    equal(first.x, 300)
    equal(Layout.Intersects(first, reserved[1]), false)
    table.insert(reserved, first)
    local second = assert(Layout.Bubble(area, reserved, "right", 594, 52))
    contained(first, area)
    contained(second, area)
    equal(Layout.Intersects(first, second), false)
    equal(Layout.Intersects(second, reserved[1]), false)
end)

test("floating bubble can fall back to the other edge", function()
    local area = Layout.Rect(0, 0, 300, 500)
    local right = Layout.Rect(240, 0, 60, 500)
    equal(assert(Layout.Bubble(area, { right }, "right", 460, 52)).x, 0)
    equal(Layout.Bubble(area, { area }, "left", 100, 52), nil)
end)

test("free bubbles keep a center drop and preserve relative position through rotation", function()
    local portrait = Layout.Rect(0, 0, 393, 814)
    local landscape = Layout.Rect(0, 0, 850, 329)
    local centerDrop = Layout.Rect(170.5, 381, 52, 52)
    local anchor = Layout.BubbleAnchor(centerDrop, portrait)
    equal(anchor.x, 0.5)
    equal(anchor.y, 0.5)
    local rotated = assert(Layout.FreeBubble(landscape, {}, anchor, 52))
    equal(rotated.x, 399)
    equal(rotated.y, 138.5)
    local restored = assert(Layout.FreeBubble(portrait, {}, anchor, 52))
    equal(restored.x, centerDrop.x)
    equal(restored.y, centerDrop.y)
end)

test("free bubbles move the shortest distance around occupied regions", function()
    local area = Layout.Rect(0, 0, 850, 329)
    local jump = Layout.Rect(725, 220, 125, 109)
    local first = assert(Layout.FreeBubble(area, { jump }, { x = 1, y = 1 }, 52))
    equal(first.x, 798)
    equal(first.y, 168)
    local second = assert(Layout.FreeBubble(area, { jump, first }, { x = 1, y = 1 }, 52))
    contained(second, area)
    equal(Layout.Intersects(first, second), false)
    equal(Layout.Intersects(jump, second), false)
    equal(Layout.FreeBubble(area, { area }, { x = 0.5, y = 0.5 }, 52), nil)
end)

test("short touch layouts use a rail or bottom bar and keep their layout after input changes", function()
    local portrait = Layout.Profile(393, 814, "touch")
    local landscape = Layout.Profile(850, 329, "touch")
    local hybrid = Layout.Profile(850, 329, "gamepad", nil, true)
    equal(landscape.compactChrome, true)
    equal(hybrid.compactChrome, true)
    equal(Layout.Navigation(landscape, "auto", 500, 240, 48, 4), "left")
    equal(Layout.Navigation(landscape, "auto", 300, 210, 48, 4), "bottom")
    equal(Layout.Navigation(landscape, "auto", 200, 120, 48, 1), "hidden")
    equal(Layout.Navigation(portrait, "auto", 340, 600, 48, 4), "bottom")
    equal(Layout.Navigation(landscape, "drawer", 500, 240, 48, 4), "drawer")
end)

test("grid columns and bottom navigation account for spacing", function()
    equal(Layout.Columns(320, 4, 150, 8), 2)
    equal(Layout.Columns(900, 4, 150, 8), 4)
    equal(Layout.Columns(160, 4, 150, 8), 1)
    equal(Layout.TabCapacity(320, 62, 8), 4)
    equal(Layout.TabCapacity(260, 70, 8), 3)
end)

test("gesture ignores another pointer and distinguishes a tap", function()
    local capture = Gesture.new(6)
    local owner, pointer, other = {}, {}, {}
    local intent = { owner = owner }
    equal(capture:Begin(pointer, 40, 50, intent), true)
    equal(capture:Begin(other, 40, 50, intent), false)
    equal(capture:Move(other, 200, 300), nil)
    equal(capture:Finish(other, 50, 50), nil)
    equal(capture:Move(pointer, 42, 49), nil)
    local subject, moved = capture:Finish(pointer, 43, 50)
    equal(subject, intent)
    equal(moved, false)
end)

test("drag remains a drag after returning to origin and supports owner cancellation", function()
    local capture = Gesture.new()
    local owner = {}
    local action = { owner = owner }
    capture:Begin("a", 10, 10, action)
    local subject, dx, dy = capture:Move("a", 14, 15)
    equal(subject, action)
    equal(dx, 4)
    equal(dy, 5)
    local finished, dragged = capture:Finish("a", 10, 10)
    equal(finished, action)
    equal(dragged, true)
    capture:Begin("b", 0, 0, action)
    equal(capture:Cancel({}), nil)
    equal(capture:Cancel(owner), action)
    equal(capture:Finish("b", 99, 2), nil)
end)

test("focus restores a visible descendant and falls back when hidden", function()
    local root, parent = {}, { Visible = true }
    local function isA() return true end
    root.IsA, root.Visible = isA, true
    parent.Parent = root
    parent.IsA = isA
    local previous = {
        Visible = true, Selectable = true, Parent = parent, IsA = isA,
        IsDescendantOf = function(_, container) return container == root end,
    }
    local alternative = table.clone(previous)
    alternative.Parent = root
    local service = {}
    Focus.Restore(service, root, previous, alternative)
    equal(service.SelectedObject, previous)
    parent.Visible = false
    Focus.Restore(service, root, previous, alternative)
    equal(service.SelectedObject, alternative)
    alternative.Selectable = false
    Focus.Restore(service, root, previous, alternative)
    equal(service.SelectedObject, nil)
end)

test("gamepad focus stays in its scope and prefers the same row or column", function()
    local function isA() return true end
    local root = { Visible = true, IsA = isA }
    local children = {}
    root.GetDescendants = function() return children end
    local function control(x, y, parent, selectable)
        local object = {
            AbsolutePosition = { X = x, Y = y }, AbsoluteSize = { X = 44, Y = 44 },
            IsA = isA, Visible = true, Selectable = selectable, Parent = parent,
            IsDescendantOf = function()
                local ancestor = parent
                while ancestor do
                    if ancestor == root then return true end
                    ancestor = ancestor.Parent
                end
                return false
            end,
        }
        table.insert(children, object)
        return object
    end
    local initial = control(20, 20, root, true)
    local right = control(120, 20, root, true)
    local below = control(20, 120, root, true)
    local disabled = control(70, 20, root, false)
    local hidden = control(0, 0, root, false)
    hidden.Visible = false
    control(66, 20, hidden, true)
    equal(Focus.First(root), initial)
    equal(Focus.InDirection(root, initial, 1, 0), right)
    equal(Focus.InDirection(root, initial, 0, 1), below)
    equal(Focus.InDirection(root, initial, -1, 0), nil)
    equal(Focus.Eligible(disabled, root), false)
    root.Visible = false
    equal(Focus.First(root), nil)
end)

print(string.format("%d window tests passed", count))
