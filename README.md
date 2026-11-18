# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md) · [简体中文](README.zh-CN.md)

A customizable, mobile-first Luau UI framework for Roblox experiences.

The source provides a runtime core and a theme engine with 40 presets, scoped style overrides, contrast controls, native font fallback, and reduced motion. The Studio previews cover themes and a responsive window engine with docking, tabs and bottom sheets.

## Try it

- [Install the core in Roblox Studio](docs/core.md)
- [Run the theme preview or create a theme](docs/design-system.md)
- [Try windows, docking and mobile layouts](docs/window.md)
- [Browse the documentation](docs/index.md)

Install the [Luau CLI](https://github.com/luau-lang/luau/releases) to run the tests from the repository root.

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau-analyze src tests examples
```

See the [changelog](CHANGELOG.md) and [test evidence](evidence/phase3-checks.json).
