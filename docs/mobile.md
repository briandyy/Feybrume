# Touch layout and device acceptance

The window engine uses the safe rectangle in Roblox layout units with CoreUISafeInsets and observes root size and position. Reserve room for thumbsticks, jump controls and experience overlays in the host because safe insets alone do not cover them. Follow PreferredInput for pointer, keyboard and gamepad changes, including on touch devices. Observe supported keyboard geometry and TextBox focus. Scroll the active field into view when geometry is unavailable. [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui) · [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) · [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService) · [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) · [Mobile input](https://create.roblox.com/docs/input/mobile)

| Safe width | Default composition | Short-height or landscape behavior |
|---|---|---|
| Micro <360 | One column, full safe area, 2–3 bottom actions and overflow | Narrow drawer or rail, less ornament, scrollable body |
| Compact 360–480 | 3–4 bottom actions and overflow, stacked cards, bottom sheet | Rail or drawer, reachable actions |
| PhoneLarge >480–640 | 4–5 bottom actions including overflow, one main column | Split if wide enough, scrollable dialog |
| Tablet >640–1000 | One or two columns, rail in landscape | Conditional two-pane view and docking |
| Desktop >1000 | Multiple windows, sidebar or rail, one to four columns | Keep global controls visible and allow scrolling |

Treat safe height ≤400 as short by default. Breakpoints and navigation are configurable. Preset touch targets default to 48×48, with a 44×44 floor and 8 units between actions. On rotation, clamp position, retain IDs and scroll anchors, and restore focus to a live target. Capture an eligible pointer at its start and release it on cancellation, orientation change or modal takeover. A vertical swipe scrolls before a horizontal slider claims the gesture. A slider provides steps, plus/minus or numeric entry and a tooltip above the finger.

A color picker uses a large saturation/value plane, wide hue and alpha rails, numeric formats and draft history. A dropdown holds draft selection, cancels stale search work, virtualizes lists over 100 items and wraps chips. The short-height keyboard layout maintains reachable footer actions and scrolls the focused field into the safe area.

Provide a button alternative to long press. Tab swipes and two-finger hide are opt-in and limited to the UI region. The reopen bubble defaults to size 52, snaps to the edge and allows left- or right-handed use. Keep it clear of navigation and virtual controls. Trap focus in the top modal, close the top overlay with Back or Escape and then restore focus. Use real engine accessibility capabilities. Respect system and manual reduced motion. Haptics require opt-in and a successful device probe. Test text scaling from 80 to 160 percent, plus a 200 percent stress case with readable wrapping or scrolling.

The rules for advanced controls, gameplay gestures, haptics and performance below are acceptance targets. The current implementation lets authors reserve host-specific regions and applies left- or right-handed placement to the reopen bubble.

## Device scenarios

The window geometry and capture rules now have CLI coverage. Studio and real-device checks remain open. Control-specific scenarios belong to later phases. [Window walkthrough](window.md)

| ID | Steps | Acceptance |
|---|---|---|
| MOB-01 | Open a window at 320×568 | Primary actions are reachable in one column |
| MOB-02 | Tap between rows at 360×640 | No neighboring activation with gap 8 |
| MOB-03 | Open many tabs at 393×870 and 430×932 | Overflow preserves the active tab |
| MOB-04 | Open an editor at 640×360 | Body scrolls and Done/Cancel stay reachable |
| MOB-05 | Run at 740×360 with virtual controls | Bubble clears thumbstick and jump |
| MOB-06 | Rotate 870×393↔393×870 during a drag | Gesture cancels and the committed value remains |
| MOB-07 | Resize a split view at 768×1024 | Columns collapse while keeping IDs and flags |
| MOB-08 | Change from narrow to wide | Focused child and scroll anchor survive |
| MOB-09 | Open an EN/ID keyboard in a bottom TextBox | Caret and confirmation remain visible |
| MOB-10 | Dismiss the keyboard with a sheet open | Footer returns to the safe rectangle once |
| MOB-11 | Tap and drag a slider diagonally | Capture starts only after the threshold |
| MOB-12 | Swipe vertically from a slider row | Scrolling starts before slider capture |
| MOB-13 | Use slider plus/minus | Step and bounds apply without a drag |
| MOB-14 | Use a color picker with finger occlusion | Tooltip clears the finger, rails remain usable, Cancel rolls back |
| MOB-15 | Filter 150 dropdown items quickly | Only the latest results show and rows recycle |
| MOB-16 | Make several selections and cancel | Draft leaves values intact and chips wrap |
| MOB-17 | Drag a bubble around a notch | Bubble remains reachable and snaps outside reserved areas |
| MOB-18 | Toggle left- and right-handed layout | Bubble, navigation and actions follow the chosen side |
| MOB-19 | Long press, then cancel | Context menu leaves underlying actions untouched |
| MOB-20 | Swipe or use two fingers outside the UI | Camera and gameplay retain input |
| MOB-21 | Switch keyboard, mouse, touch or gamepad | Focus and navigation follow the preferred input |
| MOB-22 | Press Back in nested modals | One overlay closes and focus returns |
| MOB-23 | Use long EN/ID text at 80/160/200% | Text and actions remain distinct, and 200% remains scrollable |
| MOB-24 | Combine reduced motion, battery saver and low FPS | Actions work while expensive effects stop |
| MOB-25 | Try a device with and without haptics | Both show visual feedback, and vibration requires opt-in |
| MOB-26 | Sign in while offline or revoked | Status is accurate and Close/Retry remain reachable |
| MOB-27 | Drag, hide, then destroy while pressing | Pointer capture, timers, input and audio scopes release |
| MOB-28 | Compare a small target with a 48-unit target | Record misses, neighboring activations and finger occlusion |

Cover all sizes and rotations in Studio's Device Emulator. Repeat with a desktop pointer, keyboard and controller, and real low-end Android, midrange Android and iOS devices where available. Capture device, OS, Roblox version, profile, performance, input route, timestamp and expected versus actual behavior. Repeat rotations and keyboard cases in a published test experience for real permissions and Core UI.
