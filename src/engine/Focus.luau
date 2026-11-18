local Focus = {}

function Focus.Eligible(object, root)
    if not object or not object.Selectable or not object:IsDescendantOf(root) then return false end
    local ancestor = object
    while ancestor and ancestor ~= root do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
        ancestor = ancestor.Parent
    end
    return ancestor == root
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
