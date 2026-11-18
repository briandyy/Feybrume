local Fey = require("../src")
local Color = require("../src/engine/Color")
local count = 0

local function equal(actual, expected)
    assert(actual == expected, string.format("Expected %s, received %s", tostring(expected), tostring(actual)))
end

local function value(result)
    assert(result.ok, result.error and result.error.code)
    return result.value
end

local function test(name, callback)
    local ok, err = pcall(callback)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    count += 1
    print("PASS " .. name)
end

test("all 40 presets load with frozen tokens and distinct geometry", function()
    local registry = Fey.Theme.new()
    equal(#registry:List(), 40)
    equal(registry:Get().id, "feybrume-default")
    local unique = {}
    for index, theme in ipairs(registry:List()) do
        equal(theme.themeNumber, index)
        equal(theme.signature, index <= 4)
        assert(not unique[theme.geometry])
        unique[theme.geometry] = true
        assert(table.isfrozen(theme.tokens) and table.isfrozen(theme.gradient[1]))
        equal(theme.gradient[1].at, 0)
        equal(theme.gradient[#theme.gradient].at, 1)
        assert(Color.IsHex(theme.palette.surface))
    end
    registry:Destroy()
end)

test("registry changes publish token deltas and skip identical selections", function()
    local registry = Fey.Theme.new()
    local emissions, colors, wrongOrder = 0, 0, false
    local connection = registry:Subscribe(function(theme, diff, before)
        emissions += 1
        if diff["palette.surface"] then colors += 1 end
        wrongOrder = theme.id ~= "memoir" or before.id ~= "feybrume-default"
            or registry:Set("noir").ok == true
    end)
    value(registry:Set("memoir"))
    value(registry:Set("memoir"))
    equal(emissions, 1)
    equal(colors, 1)
    equal(wrongOrder, false)
    registry:Destroy()
    equal(connection.Connected, false)
    equal(registry:Set("noir").error.code, "DISPOSED")
end)

test("custom themes derive new colors and preserve base presets", function()
    local registry = Fey.Theme.new()
    local base = registry:Get("noir")
    local patch = { id = "plum", inherits = "noir", name = "Plum", radius = 9, palette = { accent = "#B274D8" } }
    local custom = value(registry:Register(patch))
    equal(custom.signature, false)
    equal(custom.palette.accent, "#B274D8")
    equal(custom.palette.background, base.palette.background)
    assert(custom.tokens.selection ~= base.tokens.selection)
    patch.palette.accent = "#FFFFFF"
    equal(registry:Get("plum").palette.accent, "#B274D8")
    equal(registry:Get("noir"), base)
    equal(registry:Register(patch).error.code, "DUPLICATE_THEME")
    equal(registry:Register({ id = "missing", inherits = "unknown" }).error.code, "THEME_NOT_FOUND")
    equal(registry:Register({ id = "broken", palette = { surface = "blue" } }).error.code, "INVALID_VALUE")
    equal(registry:Derive("noir", { spacing = 10 }).error.code, "INVALID_VALUE")
    equal(registry:Derive("noir", { gradient = { { at = 1, color = "#FFFFFF" }, { at = 0, color = "#000000" } } }).error.code, "INVALID_VALUE")
    equal(#registry:List(), 41)
end)

test("override precedence, focus and mobile target minimum", function()
    local registry = Fey.Theme.new()
    local style = value(Fey.StyleResolver.Resolve(registry:Get(), {
        input = "touch", states = { selected = true, focused = true },
        accessibility = { fontScale = 1.5 },
        overrides = {
            framework = { size = "XL", radius = 3 },
            window = { radius = 4, variant = "outline" },
            container = { radius = 5 },
            component = { radius = 6, size = "XS" },
            state = { radius = 7, textSize = 18 },
        },
    }))
    equal(style.radius, 7)
    equal(style.variant, "outline")
    equal(style.size, "XS")
    equal(style.state, "selected")
    equal(style.textSize, 27)
    assert(style.minHeight >= 48 and style.minWidth >= 48)
    assert(style.focus.width == 2 and style.indicator == "check")
    equal(Fey.StyleResolver.Resolve(registry:Get(), { overrides = { window = { radius = -1 } } }).error.code, "INVALID_VALUE")
    equal(Fey.StyleResolver.Resolve(registry:Get(), { accessibility = { fontScale = 3 } }).error.code, "INVALID_VALUE")
end)

test("all presets, variants and states meet contrast over solid surfaces", function()
    local registry = Fey.Theme.new()
    local states = { "default", "hovered", "pressed", "focused", "selected", "loading", "disabled", "locked", "invalid", "success" }
    local total = 0
    for _, theme in ipairs(registry:List()) do
        for variant in pairs(Fey.Tokens.Variants) do
            for _, state in ipairs(states) do
                local style = value(Fey.StyleResolver.Resolve(theme, {
                    states = state,
                    overrides = { component = { variant = variant } },
                }))
                assert(Color.Contrast(style.foreground, style.compositeBackground) >= 4.5, theme.id .. " " .. variant .. " " .. state)
                if style.borderWidth > 0 then assert(Color.Contrast(style.stroke, theme.palette.surface) >= 3) end
                if state == "focused" then
                    assert(Color.Contrast(style.focus.inner, style.compositeBackground) >= 3)
                    assert(Color.Contrast(style.focus.outer, theme.palette.surface) >= 3)
                end
                if state == "disabled" or state == "invalid" or state == "success" then assert(style.indicator) end
                total += 1
            end
        end
    end
    equal(total, 3200)
end)

test("transparent fills use their real backdrop and contrast can warn", function()
    local theme = Fey.Theme.new():Get()
    local options = {
        parentSurface = "#FFFFFF",
        overrides = { component = { variant = "glass", background = "#000000", foreground = "#CCCCCC", backgroundOpacity = 0.15 } },
        accessibility = { autoContrast = false },
        states = { hovered = true, focused = true },
        input = "touch",
    }
    local styled = value(Fey.StyleResolver.Resolve(theme, options))
    equal(styled.state, "default")
    equal(styled.compositeBackground, "#D9D9D9")
    equal(styled.foreground, "#CCCCCC")
    assert(table.find(styled.warnings, "TEXT_CONTRAST"))
    options.accessibility.autoContrast = true
    local corrected = value(Fey.StyleResolver.Resolve(theme, options))
    assert(Color.Contrast(corrected.foreground, corrected.compositeBackground) >= 4.5)
    assert(Fey.StyleResolver.Diff(styled, corrected).foreground)
end)

test("native font resolver tries preferred face, theme family and fallback", function()
    local theme = Fey.Theme.new():Get("memoir")
    local calls = {}
    local resolver = Fey.Typography.new(function(candidate)
        table.insert(calls, candidate.family or candidate.assetId)
        if candidate.family == "BuilderSans" then return "native-face" end
        error("unavailable")
    end)
    local selected = value(resolver:Resolve(theme, "title", { assetId = 123 }))
    equal(table.concat(calls, ","), "123,Merriweather,BuilderSans")
    equal(selected.fallback, true)
    equal(selected.selected.weight, "Bold")
    local textBox = { Text = "中文 dan Indonesia", CursorPosition = 4, SelectionStart = 1 }
    value(Fey.Typography.Apply(textBox, selected, 17))
    equal(textBox.FontFace, "native-face")
    equal(textBox.TextSize, 17)
    equal(textBox.CursorPosition, 4)
    equal(textBox.SelectionStart, 1)
    equal(textBox.Text, "中文 dan Indonesia")
    equal(resolver:Resolve(theme, "body", { family = "rbxassetid://12" }).error.code, "INVALID_VALUE")
    equal(Fey.Typography.new(function() return nil end):Resolve(theme, "body").error.code, "FONT_UNAVAILABLE")
end)

test("font fallback handles rejected and throwing load probes without repeating them", function()
    local theme = Fey.Theme.new():Get("cultivation")
    local checked = {}
    local resolver = Fey.Typography.new(function(candidate)
        return candidate.family
    end, function(face)
        table.insert(checked, face)
        if face == "Bodoni" then return false end
        if face == "BuilderSans" then error("font could not be loaded") end
        return face == "SourceSans"
    end)
    local first = value(resolver:Resolve(theme, "title"))
    equal(first.face, "SourceSans")
    equal(first.fallback, true)
    equal(table.concat(checked, ","), "Bodoni,BuilderSans,SourceSans")
    equal(value(resolver:Resolve(theme, "title")).face, "SourceSans")
    equal(#checked, 3)
end)

test("native font test can yield before selecting fallback", function()
    local theme = Fey.Theme.new():Get("cultivation")
    local resolver = Fey.Typography.new(function(candidate) return candidate.family end, function(face)
        if face == "Bodoni" then return coroutine.yield(face) end
        return true
    end)
    local selected
    local thread = coroutine.create(function()
        selected = value(resolver:Resolve(theme, "title"))
    end)
    local ok, first = coroutine.resume(thread)
    equal(ok, true)
    equal(first, "Bodoni")
    equal(selected, nil)
    equal(coroutine.resume(thread, false), true)
    equal(selected.face, "BuilderSans")
    equal(selected.fallback, true)
end)

test("reduced motion is honored for every profile", function()
    local registry = Fey.Theme.new()
    for _, theme in ipairs(registry:List()) do
        equal(Fey.Motion.Resolve(theme.motion.profile, { systemReducedMotion = true }).seconds, 0)
        equal(Fey.Motion.Resolve(theme.motion.profile, { reducedMotion = "always" }).seconds, 0)
        if theme.motion.profile ~= "instant" then
            assert(Fey.Motion.Resolve(theme.motion.profile, { reducedMotion = "never", systemReducedMotion = true }).seconds > 0)
        end
    end
end)

test("transition cancels old work, skips no-op and releases scope resources", function()
    local built = {}
    local scope = Fey.Janitor.new()
    local transition = Fey.Transition.new({
        read = function(target, key)
            assert(key ~= "invalid", "Unknown property")
            return target[key]
        end,
        write = function(target, props) for key, item in pairs(props) do target[key] = item end end,
        create = function(target, goals, _, finish)
            local record = {
                play = 0, cancelled = 0, destroyed = 0,
                finish = finish,
                complete = function()
                    for key, goal in pairs(goals) do target[key] = goal end
                    finish()
                end,
            }
            table.insert(built, record)
            return {
                Play = function() record.play += 1 end,
                Cancel = function()
                    record.cancelled += 1
                    finish()
                end,
                Destroy = function() record.destroyed += 1 end,
            }
        end,
    }, scope)
    local target = { x = 0, y = 0 }
    local normal, reduced = Fey.Motion.Resolve("calm"), Fey.Motion.Resolve("instant")
    local animated = { x = true }
    equal(value(transition:Apply(target, { x = 1, y = 2 }, normal, animated)), true)
    equal(target.y, 2)
    equal(target.x, 0)
    equal(value(transition:Apply(target, { x = 1, y = 2 }, normal, animated)), false)
    equal(transition:Apply(target, { invalid = true }, normal, animated).ok, false)
    equal(built[1].cancelled, 0)
    equal(value(transition:Apply(target, { x = 2 }, normal, animated)), true)
    equal(built[1].cancelled, 1)
    built[1].finish()
    equal(built[2].destroyed, 0)
    built[2].complete()
    equal(built[2].destroyed, 1)
    equal(target.x, 2)
    equal(value(transition:Apply(target, { x = 3 }, reduced, animated)), true)
    equal(target.x, 3)
    equal(#built, 2)
    value(transition:Apply(target, { x = 9 }, normal, animated))
    scope:Destroy()
    equal(built[3].cancelled, 1)
    equal(built[3].destroyed, 1)
    equal(scope:GetCounts().resources, 0)
end)

print(string.format("%d theme tests passed", count))
