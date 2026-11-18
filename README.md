# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md) · [简体中文](README.zh-CN.md)

A customizable, mobile-first Luau UI framework for Roblox experiences.

The source provides a runtime core and a theme engine with 40 presets, scoped style overrides, contrast controls, native font fallback, and reduced motion. The Studio preview shows the presets on a sample control. The window and layout engine is planned for the next phase.

## Try it

- [Install the core in Roblox Studio](docs/core.md)
- [Run the theme preview or create a theme](docs/design-system.md)
- [Browse the documentation](docs/index.md)

Install the [Luau CLI](https://github.com/luau-lang/luau/releases) to run the tests from the repository root.

```sh
luau tests/core.luau
luau tests/theme.luau
luau-analyze src tests examples
```

See the [changelog](CHANGELOG.md) and [test evidence](evidence/phase2-checks.json).
