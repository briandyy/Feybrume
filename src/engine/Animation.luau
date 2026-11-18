local Animation = {}

function Animation.RobloxAdapter(services)
    return table.freeze({
        read = function(target, property)
            return target[property]
        end,
        write = function(target, properties)
            for property, value in pairs(properties) do target[property] = value end
        end,
        create = function(target, goals, motion, finish)
            local tweenInfo = TweenInfo.new(motion.seconds, Enum.EasingStyle[motion.easing], Enum.EasingDirection[motion.direction])
            local tween = services:Get("TweenService"):Create(target, tweenInfo, goals)
            local connection = tween.Completed:Connect(finish)
            return {
                Play = function() tween:Play() end,
                Cancel = function() tween:Cancel() end,
                Destroy = function()
                    connection:Disconnect()
                    tween:Destroy()
                end,
            }
        end,
    })
end

return table.freeze(Animation)
