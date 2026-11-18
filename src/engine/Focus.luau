local Focus = {}

function Focus.Eligible(object, root)
    if not object or not object.Selectable or not object:IsDescendantOf(root) then return false end
    local ancestor = object
    while ancestor and ancestor ~= root do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
        ancestor = ancestor.Parent
    end
    return ancestor == root and (not root:IsA("GuiObject") or root.Visible)
end

function Focus.First(root)
    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("GuiObject") and Focus.Eligible(object, root) then return object end
    end
    return nil
end

function Focus.InDirection(root, selected, directionX, directionY)
    local position, size = selected.AbsolutePosition, selected.AbsoluteSize
    local originX, originY = position.X + size.X / 2, position.Y + size.Y / 2
    local best, bestCost
    for _, object in ipairs(root:GetDescendants()) do
        if object ~= selected and object:IsA("GuiObject") and Focus.Eligible(object, root) then
            local bounds = object.AbsoluteSize
            if bounds.X > 0 and bounds.Y > 0 then
                local point = object.AbsolutePosition
                local dx, dy = point.X + bounds.X / 2 - originX, point.Y + bounds.Y / 2 - originY
                local forward = dx * directionX + dy * directionY
                if forward > 1 then
                    local across = math.abs(dx * directionY + dy * directionX)
                    local cost = forward + across * 3
                    if not bestCost or cost < bestCost then best, bestCost = object, cost end
                end
            end
        end
    end
    return best
end

function Focus.Restore(service, root, previous, fallback)
    if Focus.Eligible(previous, root) then
        service.SelectedObject = previous
    elseif Focus.Eligible(fallback, root) then
        service.SelectedObject = fallback
    else
        service.SelectedObject = nil
    end
end

return table.freeze(Focus)
