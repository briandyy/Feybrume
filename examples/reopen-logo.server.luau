local HttpService = game:GetService("HttpService")
local storage = game:GetService("ReplicatedStorage")
local PNG = require(script.Parent.PngDecoder)
local Style = require(storage:WaitForChild("Feybrume").ui.ReopenStyle)

-- Preview allowlist. Add exact PNG URLs from a CDN you control or trust.
-- Rocket graphic from Twemoji by Twitter, Inc. and contributors, CC BY 4.0.
-- https://github.com/twitter/twemoji/tree/v14.0.2 and https://creativecommons.org/licenses/by/4.0/
local approvedUrls = {
    ["https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f680.png"] = true,
}
local jobs = {}
local maximumBytes = 64 * 1024

local function fetch(url)
    local response = HttpService:RequestAsync({ Url = url, Method = "GET" })
    local body = response.Body
    assert(response.Success and #body >= 33 and #body <= maximumBytes, "Invalid PNG response")
    assert(body:sub(1, 8) == "\137PNG\r\n\26\n" and body:sub(13, 16) == "IHDR", "Expected PNG")
    local width, height = string.unpack(">I4I4", body, 17)
    local max = Style.MaxImageDimension
    assert(width >= 1 and width <= max and height >= 1 and height <= max, "PNG size out of range")
    local image = PNG.decode(buffer.fromstring(body))
    assert(Style.IsPixelImage(image), "Invalid decoded PNG")
    return { width = image.width, height = image.height, pixels = image.pixels }
end

local remote = Instance.new("RemoteFunction")
remote.Name = "FeybrumePreviewLogo"
remote.OnServerInvoke = function(_, url)
    if not Style.IsImageUrl(url) or not approvedUrls[url] then return nil, "URL not registered" end
    local job = jobs[url]
    if job then
        if not job.complete then job.ready.Event:Wait() end
    else
        job = { ready = Instance.new("BindableEvent") }
        jobs[url] = job
        local ok, image = pcall(fetch, url)
        if ok then job.image = image end
        job.complete = true
        job.ready:Fire()
    end
    return job.image, if job.image then nil else "PNG load failed. Check HTTP settings and restart the test."
end
remote.Parent = storage
