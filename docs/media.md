# Media and audio

Media resolution checks source syntax, policy and backend capability. Loading then checks asset permissions, readiness and playback independently. This document describes the Phase 7 source and playback contracts. The window layer supplies native hosts for `Background`, `Overlay`, `TopbarLeading`, `TopbarTrailing`, and `StatusBar`. The Phase 3 reopen button supports Roblox assets and a scoped HTTPS pixel resolver, demonstrated with an allowlisted CDN PNG. [Reopen button setup](window.md#customize-the-reopen-button)

| Source | Images and animation | Video and audio | Acceptance |
|---|---|---|---|
| Permitted asset ID or `rbxassetid://` | Native ImageLabel. Convert GIF and crop sprite frames. | Native VideoFrame or Sound/AudioPlayer. | MED-01: permitted, denied, missing, wrong type and moderated |
| Documented `rbxasset://` | Native for applicable engine paths and valid sprite metadata. | Use only verified engine paths and types. | MED-02: valid path, unknown path and wrong type |
| Supported `rbxthumb://` | Native thumbnail. | Video poster or no audio. | MED-03: ready and timeout |
| HTTPS, CDN or R2 | Import assets through a permitted build step. | Import to Roblox or offer a policy-compliant handoff on a verified host. | MED-04: direct URL verdict and fallback |
| Local path | Build-time import or a host adapter with demonstrated access. | Build-time import or verified adapter. | MED-05: unavailable in normal Roblox Studio, explicit host probe |
| Approved atlas | Native image crops and scripted frame sequencing. | Optional video poster. | MED-06: bounds, seeking and frame durations |
| YouTube source | Card or permitted poster. | External handoff where allowed. Native VideoFrame cannot play the URL. | MED-07: valid and invalid URLs, unavailable handoff |
| Registered source | Resolve through the same checks. | Resolve through the same checks. | MED-08: cycles and unknown references rejected |
| Approved model Instance | ViewportFrame with Camera and WorldModel. | No video or audio asset. | MED-09: orbit and clone cleanup |

`ImageLabel` supports asset images and spritesheet regions. `EditableImage` has permission and memory requirements. `VideoFrame` uses permitted Roblox video assets. Asset path syntax alone does not prove load access. Verify clipping, scrubbing, captions and concurrent video on a published device target. [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) · [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) · [VideoFrame](https://create.roblox.com/docs/reference/engine/classes/VideoFrame) · [Video assets](https://create.roblox.com/docs/ui/video-frames) · [AudioPlayer](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer) · [Audio assets](https://create.roblox.com/docs/audio/assets)

## Source and handle contracts

`kind` supports image, gif, video, audio, sprite, viewport, and youtube. `source` carries `{type, value}`, with types robloxAsset, robloxUri, https, local, atlas, youtube and registered. Viewport3D also accepts an approved model Instance. Shorthands `assetId`, `url`, and `localPath` are mutually exclusive. ID 0 is invalid. Normalize a top-level `type` alias to `kind`, a named slot to slot placement and `content` to the default content slot. Placement supports slot, absolute, background or overlay. Fit supports contain, cover, fill or none. The default load policy is whenVisible, with manual and eager alternatives. Autoplay and looping default to false, mute defaults to true and opacity defaults to 1. Size accepts a UDim2 or slot constraints and anchor accepts a Vector2.

`Resolve(request, context)` returns `{ok, backend?, capability, reason?, suggestedConversion?, fallback?, permissionState}`. Resolution makes no HTTP request. Permission starts unknown. Lifecycle moves from idle to pending and then ready or failed. Playback tracks stopped, playing or paused. Window hide can pause, release or preserve playback. A changed source or closed window invalidates the run and releases timers, connections and references. Cache keys include source, version, host and permission epoch.

Handles provide `SetSource/SetPosition/SetSize/SetSlot/SetFit/SetPoster/Play/Pause/Stop/Seek/SetVolume/Destroy`. Unavailable operations return `UNSUPPORTED_OPERATION`. Slots support hero, logo, splash, header, background, section, card, tooltip, toast, modal, footer and widget placement. If a poster is unavailable, show text and a reason code.

Validate HTTPS hosts with exact allowlists and bounded URLs, response sizes, and timeouts. Strip credentials and tracking parameters. YouTube IDs use eleven URL-safe characters. Rebuild a canonical watch URL from a permitted host and ID. External actions require user intent, host permission and platform policy. Published Roblox experiences must follow off-platform rules for links and QR codes. An approved import pipeline fetches from a permitted source, validates and converts offline, uploads under an authorized owner, records grants and moderation, and stores checksums. Never derive a Roblox video asset from an unauthorized YouTube stream. [YouTube API policies](https://developers.google.com/youtube/terms/developer-policies) · [Roblox Community Standards](https://about.roblox.com/community-standards) · [Roblox asset operations](https://create.roblox.com/docs/cloud/reference/features/assets)

## Animated images

Compose GIF, APNG or WebP frames with disposal and alpha, then record dimensions, offsets, trimming, durations and loop count. Pack padded sheets with per-page checksums and grants. Drive playback with elapsed monotonic time, cumulative durations, bounded frame skipping and visibility. Support seeking, reverse and ping-pong. Pause or show a poster with reduced motion. Keep decorations from consuming input.

## Audio

Use scoped music buses for login, main, loading and ambient music. Keep UI, success, error, notification and custom sound effects separate. Clamp master × bus × track volume. Default to silent playback, require consent for audible autoplay, and apply mute immediately. For an authorized login transition, fade between two ready sources and handle partial errors without duplicating playback. Playlists support queue, repeat, shuffle, intro and fades. Window hide follows pause, duck or mute policy. Apply cooldown, priority and deduplication with up to eight configurable simultaneous effects. The Silent pack is empty by design. Named sound packs await permitted assets. MED-10 covers consent, crossfade, voice caps, errors, hide and scope cleanup.
