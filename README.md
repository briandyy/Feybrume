# Feybrume

A customizable, mobile-first Luau UI framework for Roblox experiences, with responsive components, themes, and capability-aware media support.

Feybrume is in development. The current source includes the runtime foundation for service lookup, resource cleanup, signals, cancellable tasks, and state. The interface and theme engine are still in design.

## Run the core tests

Install the [Luau CLI](https://github.com/luau-lang/luau/releases) and run these commands from the repository root.

```sh
luau tests/core.luau
luau-analyze src tests
```

See the [core guide](docs/core.md) for Studio setup, API examples, and runtime limits.

## Documentation

- [Documentation index](docs/index.md)
- [Architecture](docs/architecture.md)
- [Component inventory](design/components.json) and [theme registry](design/themes.json)
- [Changelog](CHANGELOG.md)
