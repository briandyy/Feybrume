local ControlSpec = require("../src/ui/ControlSpec")
local ControlBase = require("../src/ui/ControlBase")
local Container = require("../src/ui/Container")
local Flags = require("../src/core/Flags")
local Runtime = require("../src/core/Runtime")
local StyleResolver = require("../src/engine/StyleResolver")
local Theme = require("../src/engine/Theme")
local FakeHost = require("./FakeHost")

local count = 0
local function verify(name, run)
    local ok, detail = xpcall(run, debug.traceback)
    if not ok then error(name .. "\n" .. tostring(detail), 0) end
    count += 1
    print("PASS " .. name)
end

local function equal(actual, expected)
    assert(actual == expected, `Expected {tostring(expected)}, received {tostring(actual)}`)
end

local function context()
    local host = FakeHost.new()
    local runtime = Runtime.Create(host)
    local flags = Flags.new(runtime:CreateStore())
    local errors = {}
    return {
        flags = flags, clock = runtime.Clock, namespace = "fixture", host = host, runtime = runtime,
        report = function(errorValue) table.insert(errors, errorValue.code) end,
        errors = errors,
    }
end

local function control(ctx, kind, props)
    local prepared = ControlSpec.Mount(kind, props)
    assert(prepared.ok, kind)
    local model = ControlBase.new(ctx, prepared.value)
    assert(model.ok, kind)
    ctx.runtime.Scope:Give(model.value, nil, model.value)
    model.value:OnDestroyed(function(handle) ctx.runtime.Scope:Remove(handle) end)
    return model.value
end

local radioOptions = {
    { id = "easy", name = "Easy" },
    { id = "standard", name = "Standard" },
    { id = "hard", name = "Hard", disabled = true },
}
local defaults = {
    Label = "Label", Heading = "Heading", Subheading = "Subheading", Paragraph = "Paragraph",
    RichText = "RichText", Caption = "Caption", TextDivider = "TextDivider", IconText = "IconText",
    Statistic = 27, Quote = "Quote", Button = true, IconButton = true,
    Toggle = false, Checkbox = false, Radio = false, RadioGroup = "easy", Tag = "Tag", Badge = "Badge",
}

verify("all 18 foundation catalog entries have a container factory and a validated model", function()
    local ctx = context()
    local n = 0
    for kind, definition in pairs(ControlSpec.Definitions) do
        assert(type(Container[kind]) == "function", kind)
        local expected = defaults[kind]
        assert(expected ~= nil, kind)
        local props = if definition.group then { options = radioOptions }
            elseif definition.metric then { default = expected } else { name = kind }
        local item = control(ctx, kind, props)
        if definition.model == "action" then
            equal(item:Get().error.code, "UNSUPPORTED_OPERATION")
        else
            equal(item:Get().value, expected)
        end
        n += 1
    end
    equal(n, 18)
    ctx.runtime:Dispose()
end)

verify("display values update and reset with real types and unsupported actions fail", function()
    local ctx = context()
    local item = control(ctx, "Statistic", { name = "Laps", unit = "laps", default = 2 })
    local validation
    item:OnValidate(function(result) validation = result.ok end)
    assert(item:Set(5).ok)
    equal(validation, true)
    equal(item:Serialize().value.value, 5)
    equal(item:Set("invalid").error.code, "INVALID_VALUE")
    equal(validation, false)
    equal(item:Set(math.huge).error.code, "INVALID_VALUE")
    equal(item:Focus().error.code, "UNSUPPORTED_OPERATION")
    equal(item:Activate().error.code, "UNSUPPORTED_OPERATION")
    assert(item:Reset().ok)
    equal(item:Get().value, 2)
    ctx.runtime:Dispose()
end)

verify("rich text accepts simple spans and escapes tags, attributes, and incomplete markup", function()
    local html = '<b>Ready</b> & <font color="#fff">bad</font><br /><i>open'
    equal(ControlSpec.SafeRichText(html), '<b>Ready</b> &amp; &lt;font color="#fff"&gt;bad&lt;/font&gt;<br/><i>open</i>')
    equal(ControlSpec.SafeRichText("</b><i>unfinished<"), "&lt;/b&gt;<i>unfinished&lt;</i>")
    equal(ControlSpec.SafeRichText([[<font color='#bba8ff'><b>Accent</b></font>]]),
        [[<font color="#BBA8FF"><b>Accent</b></font>]])
    equal(ControlSpec.SafeRichText([[<font color="#BBA8FF" size="90">Ignored</font>]]),
        [[&lt;font color="#BBA8FF" size="90"&gt;Ignored&lt;/font&gt;]])
end)

verify("icon sources accept Roblox IDs and preserve the no-icon fallback", function()
    equal(ControlSpec.IconUri(12345), "rbxassetid://12345")
    equal(ControlSpec.IconUri("rbxassetid://12345"), "rbxassetid://12345")
    equal(ControlSpec.IconUri(false), nil)
    equal(ControlSpec.IconUri("https://example.com/icon.png"), nil)
    equal(ControlSpec.Mount("IconButton", { name = "Open", icon = 0 }).error.code, "INVALID_VALUE")
end)

verify("interactive variants keep minimum touch height across all supported sizes", function()
    local theme = Theme.new():Get()
    for _, spec in pairs(ControlSpec.Definitions) do
        if spec.model == "display" then continue end
        for _, size in ipairs({ "XS", "S", "M", "L", "XL", "2XL" }) do
            local design = StyleResolver.Resolve(theme, {
                input = "touch", overrides = { component = { size = size, variant = spec.style } },
                accessibility = { fontScale = 1.6 },
            })
            assert(design.ok and design.value.minHeight >= 44, spec.kind)
        end
    end
end)

verify("invalid property patches preserve the current name, visibility, and handler", function()
    local ctx = context()
    local item = control(ctx, "Button", { name = "Start" })
    assert(not item:SetProps({ name = "Stop", visible = false, size = "bad" }).ok)
    equal(item._props.name, "Start")
    equal(item._visible, true)
    assert(item:SetProps({ name = "Stop", description = "Ends the session" }).ok)
    equal(item._props.name, "Stop")
    equal(item._props.description, "Ends the session")
    assert(not item:SetProps({ onChanged = function() end }).ok)
    equal(item:Set(false).error.code, "UNSUPPORTED_OPERATION")
    ctx.runtime:Dispose()
end)

verify("button actions fire once and ignore hidden, disabled, locked, and loading controls", function()
    local ctx = context()
    local calls, source = 0, ""
    local button = control(ctx, "Button", { onClick = function(tag)
        calls += 1
        source = tag
    end })
    assert(button:_activate(nil, "user").ok)
    equal(source, "user")
    equal(calls, 1)
    for _, prop in ipairs({ "disabled", "locked", "loading" }) do
        button:SetProps({ [prop] = true })
        equal(button:_activate(nil, "user").error.code, "CONTROL_INACTIVE")
        button:SetProps({ [prop] = false })
    end
    button:Hide()
    equal(button:Activate().error.code, "CONTROL_INACTIVE")
    button:Show()
    assert(button:Activate().ok)
    equal(calls, 2)
    equal(source, "programmatic")
    ctx.runtime:Dispose()
end)

verify("a toggle and a checkbox change on release with one change event per activation", function()
    local ctx = context()
    for _, kind in ipairs({ "Toggle", "Checkbox" }) do
        local item = control(ctx, kind)
        local values, sources = {}, {}
        item:OnChanged(function(value, _, source)
            table.insert(values, value)
            table.insert(sources, source)
        end)
        item:_activate(nil, "user")
        item:_activate(nil, "user")
        equal(#values, 2)
        equal(values[1], true)
        equal(values[2], false)
        equal(sources[2], "user")
        assert(item:Set(false).ok)
        equal(#values, 2)
    end
    ctx.runtime:Dispose()
end)

verify("radio choice IDs are stable, disabled choices fail, and independent groups stay independent", function()
    local ctx = context()
    local group = control(ctx, "RadioGroup", { options = radioOptions, flag = "difficulty" })
    local other = control(ctx, "RadioGroup", { options = radioOptions, flag = "other" })
    local radio = control(ctx, "Radio")
    group:_activate("standard", "user")
    equal(group:Get().value, "standard")
    equal(other:Get().value, "easy")
    equal(group:_activate("hard", "user").error.code, "INVALID_VALUE")
    equal(group:Set("unknown").error.code, "INVALID_VALUE")
    radio:_activate(nil, "user")
    radio:_activate(nil, "user")
    equal(radio:Get().value, true)
    equal(ControlSpec.Mount("RadioGroup", { options = { radioOptions[3] } }).ok, false)
    ctx.runtime:Dispose()
end)

verify("shared flags synchronize both controls, with namespace collision and silent change behavior", function()
    local ctx = context()
    local first = control(ctx, "Toggle", { flag = "tips", shared = true, persist = true })
    local second = control(ctx, "Checkbox", { flag = "tips", shared = true, persist = true })
    local other = control(ctx, "Toggle", { flag = "tips", flagNamespace = "other" })
    local changes = {}
    second:OnChanged(function(value, previous, source)
        table.insert(changes, { value, previous, source })
    end)
    assert(first:_activate(nil, "user").ok)
    equal(second:Get().value, true)
    equal(other:Get().value, false)
    equal(changes[1][1], true)
    equal(changes[1][2], false)
    equal(changes[1][3], "user")
    assert(first:Set(false, { silent = true }).ok)
    equal(second:Get().value, false)
    equal(#changes, 1)
    local duplicate = ControlBase.new(ctx, ControlSpec.Mount("Toggle", { flag = "tips" }).value)
    equal(duplicate.error.code, "DUPLICATE_FLAG")
    ctx.runtime:Dispose()
end)

verify("restores persisted flags in one transaction and rolls back incompatible values", function()
    local ctx = context()
    local difficulty = control(ctx, "RadioGroup", { flag = "difficulty", persist = true, options = radioOptions })
    local tips = control(ctx, "Checkbox", { flag = "tips", persist = true, default = true })
    local session = control(ctx, "Toggle", { flag = "session" })
    local restored
    tips:OnChanged(function(_, _, source) restored = source end)
    local bad = ctx.flags:Restore("fixture", { difficulty = "hard", tips = false })
    assert(not bad.ok)
    equal(tips:Get().value, true)
    equal(difficulty:Get().value, "easy")
    assert(ctx.flags:Restore("fixture", { difficulty = "standard", tips = false, session = true }).ok)
    equal(restored, "restore")
    equal(tips:Get().value, false)
    equal(session:Get().value, false)
    local exported = ctx.flags:Export("fixture")
    equal(exported.difficulty, "standard")
    equal(exported.tips, false)
    equal(exported.session, nil)
    ctx.runtime:Dispose()
end)

verify("conditional UI reacts to flags and reports bad predicates without blocking good updates", function()
    local ctx = context()
    local toggle = control(ctx, "Toggle", { flag = "tips" })
    local label = control(ctx, "Paragraph", { visibleIf = function(state) return state.tips end })
    local button = control(ctx, "Button", { enabledIf = function(state) return state.tips end })
    local gate = control(ctx, "Button", { lockedIf = function(state) return state.tips end })
    equal(label._visible, false)
    equal(button._disabled, true)
    equal(gate._locked, false)
    toggle:Set(true)
    equal(label._visible, true)
    equal(button._disabled, false)
    equal(gate._locked, true)
    button:SetProps({ enabledIf = function() error("private data") end })
    equal(button._disabled, true)
    equal(ctx.errors[#ctx.errors], "CALLBACK_FAILED")
    ctx.runtime:Dispose()
end)

verify("callback failures reach diagnostics and destruction cancels a pending debounce", function()
    local ctx = context()
    local failure = control(ctx, "Button", { onClick = function() error("example") end })
    local observed
    failure:OnError(function(errorValue) observed = errorValue.code end)
    assert(failure:Activate().ok)
    equal(observed, "CALLBACK_FAILED")
    local countFired = 0
    local delayed = control(ctx, "Button", {
        onClick = function() countFired += 1 end,
        callbackTiming = { mode = "debounce", seconds = 1, leading = false, trailing = true },
    })
    delayed:Activate()
    delayed:Activate()
    ctx.host.advance(1)
    equal(countFired, 1)
    delayed:Activate()
    delayed:Destroy()
    delayed:Destroy()
    ctx.host.advance(1)
    equal(countFired, 1)
    equal(delayed:Activate().error.code, "DISPOSED")
    equal(ctx.host.pending(), 0)
    ctx.runtime:Dispose()
end)

verify("disposal disconnects bound controls, returns ownership to baseline, and blocks new edits", function()
    local ctx = context()
    local before = ctx.runtime.Scope:GetCounts()
    local item = control(ctx, "Toggle", { flag = "tips" })
    local changed = item:OnChanged(function() error("must be disconnected") end).value
    local disposed = 0
    item:OnDestroyed(function() disposed += 1 end)
    item:Destroy()
    equal(disposed, 1)
    equal(changed.Connected, false)
    equal(item:Set(false).error.code, "DISPOSED")
    equal(ctx.flags:Find("fixture", "tips"), nil)
    equal(ctx.runtime.Scope:GetCounts().resources, before.resources)
    ctx.runtime:Dispose()
end)

print(`{count} component tests passed`)
