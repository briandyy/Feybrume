local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Container = {}
Container.__index = Container

function Container.new(root, scope, options)
    options = options or {}
    return setmetatable({
        _root = root, _scope = scope, _slots = options.slots or { Main = root },
        _gap = options.gap or 8, _order = 0, _owned = options.owned == true,
    }, Container)
end

function Container:GetInstance()
    return self._root
end

function Container:GetSlot(name)
    return self._slots[name or "Main"]
end

function Container:Add(object, slot)
    local kind = typeof(object)
    assert(kind == "Instance" and object:IsA("GuiObject"), "Expected a GuiObject")
    local parent = self:GetSlot(slot)
    assert(parent and parent.Parent, "Slot is unavailable or destroyed")
    self._order += 1
    object.LayoutOrder = self._order
    object.Parent = parent
    return object
end

function Container:Grid(options)
    options = options or {}
    local requested, minimum, height, gap = options.columns or 2, options.minWidth or 150, options.rowHeight or 48, options.gap or self._gap
    assert(type(requested) == "number" and requested % 1 == 0 and requested >= 1 and requested <= 4,
        "Grid columns must be 1 to 4")
    assert(type(minimum) == "number" and minimum > 0 and minimum < math.huge
        and type(height) == "number" and height > 0 and height < math.huge
        and type(gap) == "number" and gap >= 0 and gap < math.huge, "Invalid grid dimensions")

    local frame = Factory.Frame(nil, options.name or "Grid", {
        Size = UDim2.new(1, 0, 0, 0),
    })
    self:Add(frame, options.slot)

    local grid = Factory.Create("UIGridLayout", frame, {
        SortOrder = Enum.SortOrder.LayoutOrder, CellPadding = UDim2.fromOffset(gap, gap),
    })
    local function reflow()
        local width = frame.AbsoluteSize.X
        local columns = Layout.Columns(width, requested, minimum, gap)
        grid.FillDirectionMaxCells = columns
        grid.CellSize = UDim2.fromOffset(math.max(1, math.floor((width - gap * (columns - 1)) / columns)), height)
    end
    local scope = self._scope:Fork()
    scope:Give(frame)
    local function fitHeight()
        frame.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y)
    end
    scope:Give(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow))
    scope:Give(grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitHeight))
    reflow()
    fitHeight()
    return Container.new(frame, scope, { gap = gap, owned = true })
end

function Container:HStack(options)
    local config = table.clone(options or {})
    config.columns = config.columns or 4
    return self:Grid(config)
end

function Container:Section(options)
    options = options or {}
    local shell = Factory.Frame(nil, options.name or "Section", {
        Size = UDim2.new(1, 0, 0, 0),
    })
    self:Add(shell, options.slot)
    local scope = self._scope:Fork()
    scope:Give(shell)
    local stack = Factory.Frame(shell, "Stack", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2,
    })
    local stackOrder = Factory.List(stack, self._gap)
    local function fitHeight()
        shell.Size = UDim2.new(1, 0, 0, math.max(0, stackOrder.AbsoluteContentSize.Y))
    end
    scope:Give(stackOrder:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitHeight))

    local slots = {
        Background = Factory.Frame(shell, "Background", { Size = UDim2.fromScale(1, 1), ZIndex = 1 }),
        Overlay = Factory.Frame(shell, "Overlay", { Size = UDim2.fromScale(1, 1), ZIndex = 3 }),
    }
    for index, name in ipairs({ "Leading", "Main", "Trailing", "Footer" }) do
        local slot = Factory.Frame(stack, name, {
            LayoutOrder = index, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
        })
        Factory.List(slot, self._gap)
        local function sync()
            for _, object in ipairs(slot:GetChildren()) do
                if object:IsA("GuiObject") then
                    slot.Visible = true
                    return
                end
            end
            slot.Visible = false
        end
        scope:Give(slot.ChildAdded:Connect(sync))
        scope:Give(slot.ChildRemoved:Connect(sync))
        slots[name] = slot
    end
    fitHeight()
    return Container.new(shell, scope, { slots = slots, gap = self._gap, owned = true })
end

function Container:Destroy()
    assert(self._owned, "Destroy this container through its tab or sheet")
    self._scope:Destroy()
end

return table.freeze(Container)
