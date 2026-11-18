local Layout = require("../src/engine/Layout")
local Gesture = require("../src/engine/Gesture")
local Focus = require("../src/engine/Focus")
local Workspace = require("../src/ui/Workspace")
local Window = require("../src/ui/Window")
local ReopenStyle = require("../src/ui/ReopenStyle")
local Factory = require("../src/engine/Factory")
local Viewport = require("../src/engine/Viewport")
local WindowProps = require("../src/ui/WindowProps")

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

test("floating windows reach each playable edge and can always move back", function()
    local screen = Layout.Rect(0, 0, 798, 326)
    local profile = Layout.Profile(screen.width, screen.height, "touch")
    local upperLeft = Layout.Window(Layout.Rect(-1200, -1200, 450, 260), screen, profile, "floating", limits, false)
    equal(upperLeft.x, 0)
    equal(upperLeft.y, 0)
    local lowerRight = Layout.Window(Layout.Rect(1200, 1200, 450, 260), screen, profile, "floating", limits, false)
    equal(lowerRight.x + lowerRight.width, 798)
    equal(lowerRight.y + lowerRight.height, 326)
    local away = Layout.Window(Layout.Rect(40, 30, 450, 260), screen, profile, "floating", limits, false)
    equal(away.x, 40)
    equal(away.y, 30)
    contained(upperLeft, screen)
    contained(lowerRight, screen)
    contained(away, screen)
end)

test("oversized launch requests fit and center below the Roblox top bar with room to drag", function()
    local screen = Layout.Rect(0, 0, 798, 326)
    local profile = Layout.Profile(screen.width, screen.height, "touch")
    local requested = Layout.OpenFloating({ width = 640, height = 455 }, screen, limits)
    local shown = Layout.Window(requested, screen, profile, "floating", limits, false)
    equal(shown.x, (screen.width - shown.width) / 2)
    equal(shown.y, (screen.height - shown.height) / 2)
    assert(screen.height - shown.height >= 48)
    equal(requested.height, 455)
    local explicit = Layout.OpenFloating({ x = 20, y = 4, width = 640, height = 455 }, screen, limits)
    equal(explicit.x, 20)
    equal(explicit.y, 4)
    local maximized = Layout.Window(requested, screen, profile, "fullscreen", limits, false)
    equal(maximized.height, screen.height)
end)

test("opening positions use fitted window sizes, allow coordinates, and default to center", function()
    local area = Layout.Rect(0, 0, 820, 400)
    local profile = Layout.Profile(area.width, area.height, "touch")
    local cases = {
        { "top-left", 0, 0 }, { "top", 1, 0 }, { "top-right", 2, 0 },
        { "left", 0, 1 }, { "center", 1, 1 }, { "right", 2, 1 },
        { "bottom-left", 0, 2 }, { "bottom", 1, 2 }, { "bottom-right", 2, 2 },
    }
    for _, case in ipairs(cases) do
        local requested = Layout.OpenFloating({ width = 440, height = 280 }, area, limits, WindowProps.Position(case[1]))
        local rect = Layout.Window(requested, area, profile, "floating", limits, false)
        equal(rect.x, case[2] * 190)
        equal(rect.y, case[3] * 60)
    end
    equal(WindowProps.Position(nil), "center")
    local named = Layout.OpenFloating({ width = 440, height = 280 }, area, limits, WindowProps.Position({ x = 70, y = 28 }))
    equal(named.x, 70)
    equal(named.y, 28)
    local legacy = Layout.OpenFloating({ width = 440, height = 280, x = 52 }, area, limits, "bottom-right")
    equal(legacy.x, 52)
    equal(legacy.y, 120)
    equal(pcall(WindowProps.Position, "bogus"), false)
    equal(pcall(WindowProps.Position, { x = 20, y = math.huge }), false)
end)

test("a wide panel reaches the physical corners even when Roblox blocks part of the top strip", function()
    local playable = Layout.Rect(0, 0, 790, 323)
    local travel = Layout.Rect(-36, -57, 862, 400)
    local lane = Layout.Rect(206, -57, 575, 57)
    local device = Layout.Rect(0, -57, 790, 380)
    local profile = Layout.Profile(playable.width, playable.height, "touch")
    local left = Layout.Window(Layout.Rect(-999, -999, 640, 455), playable, profile, "floating", limits, false, travel)
    equal(left.x, -36)
    equal(left.y, -57)
    assert(left.height < playable.height)
    local right = Layout.Window(Layout.Rect(999, 999, 640, 455), playable, profile, "floating", limits, false, travel)
    equal(right.x + right.width, 826)
    equal(right.y + right.height, 343)
    local chrome, cut, extension = Layout.WindowSurface(left, playable, device, lane)
    equal(chrome.x + left.x, 0)
    equal(chrome.y + left.y, 0)
    equal(cut, 57)
    assert(extension ~= nil)
    equal(extension.x + left.x, lane.x)
    equal(extension.y + left.y, travel.y)
    assert(extension.x + left.x + extension.width <= lane.x + lane.width)
    local middle = Layout.Window(Layout.Rect(120, 35, 640, 455), playable, profile, "floating", limits, false, travel)
    equal(middle.x, 120)
    equal(middle.y, 35)
end)

test("the top trim is skipped when a narrow window fits beside the Roblox controls", function()
    local playable = Layout.Rect(0, 0, 790, 323)
    local lane = Layout.Rect(206, -57, 575, 57)
    local device = Layout.Rect(0, -57, 790, 380)
    local right = Layout.Rect(350, -57, 420, 250)
    local chrome, cut, extension = Layout.WindowSurface(right, playable, device, lane)
    equal(chrome.y, 0)
    equal(cut, 0)
    equal(extension, nil)
    local blocked = Layout.Rect(0, -57, 180, 250)
    local _, blockedCut, blockedExtension = Layout.WindowSurface(blocked, playable, device, lane)
    equal(blockedCut, 57)
    equal(blockedExtension, nil)
end)

test("a centered brand avoids action buttons, and chrome props merge safely", function()
    local left, width = Layout.HeaderTitle(20, 312, 210, "center", 160)
    equal(left, 130)
    equal(width, 160)
    local right, narrowed = Layout.HeaderTitle(20, 150, 210, "center", 210)
    equal(right, 20)
    equal(narrowed, 130)
    local props = WindowProps.FromOptions({
        title = "", titleLogo = 123, titleLogoPosition = "after", titleAlign = "right",
        chromeButtons = { hide = { text = "Minimize", background = "#222244" } },
    })
    equal(props.titleLogo, "rbxassetid://123")
    local edited = WindowProps.Merge(props, { chromeButtons = { hide = { icon = 456 } } })
    equal(edited.chromeButtons.hide.icon, "rbxassetid://456")
    equal(edited.chromeButtons.hide.text, "Minimize")
    equal(props.chromeButtons.hide.icon, nil)
    equal(WindowProps.Merge(edited, { chromeButtons = { hide = false } }).chromeButtons.hide, nil)
    equal(pcall(WindowProps.Merge, props, { chromeButtons = { missing = { text = "X" } } }), false)
end)

test("resize stops before a floating window loses its travel in a short viewport", function()
    local screen = Layout.Rect(0, 0, 798, 326)
    local maximum = Layout.FloatingLimits(screen, limits)
    local grown = Layout.Resize(Layout.Rect(0, 0, 540, 225), screen, 900, 900, maximum)
    equal(grown.width, maximum.maxWidth)
    equal(grown.height, maximum.maxHeight)
    assert(grown.height < screen.height)
    local reduced = Layout.KeyboardArea(screen, Layout.Rect(0, 196, 798, 130))
    local floating = Layout.Window(grown, reduced, Layout.Profile(798, 326, "touch"), "floating", limits, false)
    contained(floating, reduced)
    assert(floating.height < reduced.height)
end)

test("resize grip adapts to phone, tablet, and desktop while preserving content width", function()
    local phone = Layout.ResizeGrip(Layout.Profile(850, 330, "touch"))
    local tablet = Layout.ResizeGrip(Layout.Profile(900, 730, "touch"))
    local desktop = Layout.ResizeGrip(Layout.Profile(1280, 720, "pointer"))
    equal(phone, 30)
    equal(tablet, 40)
    equal(desktop, 24)
    local floating = Layout.WindowBody(640, 320, 61, 6, phone)
    local docked = Layout.WindowBody(640, 320, 61, 6, 0)
    equal(floating.width, docked.width)
    equal(floating.width, 628)
    equal(docked.height - floating.height, phone)
end)

test("a condensed tab launcher identifies the active page by title", function()
    equal(Layout.TabLauncherLabel(0, "Setup"), "Setup")
    equal(Layout.TabLauncherLabel(0, "Guide"), "Guide")
    equal(Layout.TabLauncherLabel(0, nil), "Tabs")
    equal(Layout.TabLauncherLabel(2, "Guide"), "More")
end)

test("launcher can sit beside the Roblox controls at the top of the device safe area", function()
    local area = Layout.Rect(0, 0, 780, 395)
    local free = Layout.Rect(185, 0, 512, 58)
    local obstacles = Layout.TopbarObstacles(area, 58, free)
    local atTop = assert(Layout.FreeBubble(area, obstacles, { x = 0.5, y = 0 }, 52))
    equal(atTop.y, 0)
    assert(atTop.x >= free.x and atTop.x + atTop.width <= free.x + free.width)
    local atLeft = assert(Layout.FreeBubble(area, obstacles, { x = 0, y = 0.4 }, 52))
    equal(atLeft.x, 0)
    local unavailable = Layout.TopbarObstacles(area, 58, Layout.Rect(0, 0, 0, 0))
    local below = assert(Layout.FreeBubble(area, unavailable, { x = 0.5, y = 0 }, 52))
    equal(below.y, 58)
    local shortSlot = Layout.TopbarObstacles(area, 58, Layout.Rect(185, 0, 512, 34))
    equal(assert(Layout.FreeBubble(area, shortSlot, { x = 0.5, y = 0 }, 52)).y, 58)
end)

test("bubble reaches the right side of the device safe viewport without entering the top bar by default", function()
    local workspace = {
        _bubbleArea = Layout.Rect(0, 0, 780, 395),
        _launcherOffsetY = 58,
        _topbarObstacles = {},
    }
    local window = { _bubbleStyle = ReopenStyle.Merge(nil, {}) }
    local bounds, protected = Workspace._bubbleBounds(workspace, window)
    local right = assert(Layout.FreeBubble(bounds, protected, { x = 1, y = 0 }, 52))
    equal(right.x + right.width, 780)
    equal(right.y, 58)
    window._bubbleStyle = ReopenStyle.Merge(window._bubbleStyle, { allowTopbar = true })
    equal(Workspace._bubbleBounds(workspace, window).y, 0)
end)

test("reopen style merges overrides and validates images, size and shape", function()
    local defaults = ReopenStyle.Merge(nil, { label = "Launcher", shape = "rounded", radius = 14 })
    local custom = ReopenStyle.Merge(defaults, { size = 76, image = 14304828123, imageScale = 0.8 })
    equal(custom.label, "Launcher")
    equal(custom.size, 76)
    equal(custom.image, "rbxassetid://14304828123")
    equal(defaults.image, false)
    local _, iconRadius = ReopenStyle.Corner(custom, 76, 8)
    equal(iconRadius, 6)
    equal(ReopenStyle.Corner(ReopenStyle.Merge(custom, { shape = "circle" }), 76, 8), 0.5)
    equal(ReopenStyle.Merge(custom, { image = false }).image, false)
    equal(ReopenStyle.Merge(custom, { image = "https://example.com/icon.png" }).image,
        "https://example.com/icon.png")
    equal(pcall(ReopenStyle.Merge, custom, { image = "http://example.com/icon.png" }), false)
    equal(pcall(ReopenStyle.Merge, custom, { image = "https://example.com@other.test/icon.png" }), false)
    equal(pcall(ReopenStyle.Merge, custom, { size = 5 }), false)
    equal(pcall(ReopenStyle.Merge, custom, { shape = "triangle" }), false)
end)

test("window applies bubble customization live and keeps its old style on invalid edits", function()
    local placed = 0
    local window = {
        _bubbleStyle = ReopenStyle.Merge(nil, { label = "UI" }),
        _bubbleIcon = { Image = "", IsLoaded = false }, _bubble = {},
        _workspace = { _input = { Cancel = function() end }, _placeBubbles = function() placed += 1 end },
        _assertLive = function() end, _refreshBubbleImage = Window._refreshBubbleImage,
        _applyBubbleImage = Window._applyBubbleImage,
    }
    Window.SetReopenBubble(window, { image = "14304828123", size = 84 })
    equal(window._bubbleIcon.Image, "rbxassetid://14304828123")
    equal(window._bubble.Text, "UI")
    equal(placed, 1)
    window._bubbleIcon.IsLoaded = true
    window:_refreshBubbleImage()
    equal(window._bubble.Text, "")
    equal(pcall(Window.SetReopenBubble, window, { size = 0 }), false)
    equal(window._bubbleStyle.size, 84)
    equal(placed, 1)
    Window.SetReopenBubble(window, { image = false })
    equal(window._bubble.Text, "UI")
    equal(window._bubbleIcon.Visible, false)
end)

test("full-width launcher reaches the physical edge while movement controls stay device aligned", function()
    local device = Layout.Rect(0, -52, 780, 340)
    local full, touch = Viewport.LauncherAreas(Layout.Rect(0, 0, 860, 400), device, -40, -60)
    equal(touch.x, 40)
    equal(touch.width, 780)
    equal(full.y, 8)
    equal(full.height, 340)
    local chrome = { _bubbleArea = full, _launcherOffsetY = 60 }
    local bounds, blocked = Workspace._bubbleBounds(chrome, { _bubbleStyle = {} })
    local right = assert(Layout.FreeBubble(bounds, blocked, { x = 1, y = 0 }, 52))
    equal(right.x + right.width, 860)
    equal(right.y, 60)
    local keyboard = Viewport.LauncherAreas(Layout.Rect(0, 0, 860, 200), device, -40, -60)
    equal(keyboard.y + keyboard.height, 200)
end)

test("CDN logo data must be bounded RGBA pixels with an exact length", function()
    equal(ReopenStyle.IsPixelImage({ width = 72, height = 72, pixels = buffer.create(72 * 72 * 4) }), true)
    equal(ReopenStyle.IsPixelImage({ width = 72, height = 72, pixels = buffer.create(4) }), false)
    equal(ReopenStyle.IsPixelImage({ width = 129, height = 1, pixels = buffer.create(129 * 4) }), false)
    equal(ReopenStyle.IsPixelImage({ width = 0, height = 0, pixels = buffer.create(0) }), false)
end)

test("tab outlines have clearance from scrollbar and clipping boundaries", function()
    local first = Layout.TabBounds(140, 48, 0, 4, true)
    local last = Layout.TabBounds(140, 48, 3, 4, true)
    equal(first.x, Layout.TabPadding)
    equal(first.y, Layout.TabPadding)
    equal(first.x + first.width, 140 - Layout.TabPadding - 4)
    equal(last.y, Layout.TabPadding + 3 * (48 + 8))
    local row = Layout.TabBounds(350, 48, 3, 4, false)
    assert(row.x + row.width <= 350 - Layout.TabPadding)
    equal(row.y, Layout.TabPadding)
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

test("gamepad opens the tab list once on release and leaves other buttons alone", function()
    local root = { Visible = true, IsA = function() return true end }
    local more = {
        Visible = true, Selectable = true, Parent = root,
        IsA = root.IsA, IsDescendantOf = function(_, parent) return parent == root end,
    }
    local buttonClicks, selectedId = 0, nil
    local window = {
        _more = more, _shell = root, _nav = { Visible = true },
        _tabs = {
            { Id = "home", _button = { Text = "Home" } },
            { Id = "help", _button = { Text = "Help" }, _disabled = true },
        },
        _canInteract = function() return true end,
        SelectTab = function(_, id) selectedId = id end,
        OpenContextMenu = function(_, entries)
            buttonClicks += 1
            equal(#entries, 1)
            entries[1].callback()
        end,
        _showTabs = Window._showTabs,
    }
    local workspace = { _windows = { window }, _hasModal = function() return false end }
    local function key(state, selected, active)
        return Workspace._handleTabLauncher(workspace, state, "gamepad", selected, active ~= false)
    end
    equal(key("Begin", {}), false)
    equal(key("Begin", more), true)
    equal(buttonClicks, 0)
    equal(key("End", more), true)
    equal(buttonClicks, 1)
    equal(selectedId, "home")
    equal(key("End", more), false)
    equal(key("Begin", more), true)
    equal(key("Cancel", more), true)
    equal(key("End", more), false)
    equal(key("Begin", more), true)
    equal(key("End", {}), true)
    equal(key("Begin", more), true)
    equal(key("End", more, false), true)
    equal(buttonClicks, 1)
end)

test("window title and appearance can be updated atomically at runtime", function()
    local WindowProps = require("../src/ui/WindowProps")
    local reflowed, placed, canceled = 0, 0, 0
    local window = {
        _props = WindowProps.FromOptions({ title = "Original", navigation = "auto", sidebarWidth = 142 }),
        _workspace = {
            _input = { Cancel = function() canceled += 1 end },
            _placeBubbles = function() placed += 1 end,
        },
        _assertLive = function() end,
        _reflow = function() reflowed += 1 end,
    }
    Window.SetProps(window, { title = "Tools", subtitle = "Ready", cornerRadius = 0, backgroundOpacity = 0.8 })
    equal(window._props.title, "Tools")
    equal(window._props.subtitle, "Ready")
    equal(window._props.cornerRadius, 0)
    equal(window._props.sidebarWidth, 142)
    equal(pcall(Window.SetProps, window, { title = "Uncommitted", padding = -1 }), false)
    equal(window._props.title, "Tools")
    equal(reflowed, 1)
    equal(placed, 1)
    equal(canceled, 1)
end)

test("set bounds updates the floating restore request without undocking", function()
    local window = {
        _requested = Layout.Rect(100, 40, 550, 360), _placement = "left",
        _workspace = { _input = { Cancel = function() end }, _placeBubbles = function() end },
        _assertLive = function() end, _reflow = function() end,
    }
    Window.SetBounds(window, { x = 36, width = 420 })
    equal(window._placement, "left")
    equal(window._requested.x, 36)
    equal(window._requested.y, 40)
    equal(window._requested.width, 420)
    equal(pcall(Window.SetBounds, window, { x = 0, height = -1 }), false)
    equal(window._requested.x, 36)
end)

test("header slots reserve title space on touch-sized windows", function()
    local left, right = Layout.HeaderAdornmentWidths(240, 52, 60)
    equal(left, 52)
    equal(right, 60)
    left, right = Layout.HeaderAdornmentWidths(150, 80, 70)
    equal(left, 78)
    equal(right, 0)
    equal(Layout.HeaderAdornmentWidths(54, 50, 50), 0)
end)

print(string.format("%d window tests passed", count))
