# AGENTS

## Agent skills

### Issue tracker

GitHub issues at `XianShengXingGe/JianTie`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/`). See `docs/agents/domain.md`.

## Engineering principles

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

## Code standards

### File length and single responsibility limits
- **Target range**: Standard source files should ideally be 100–400 lines.
- **> 500 lines**: Triggers responsibility review (assess for cohesive sub-module extraction).
- **> 800 lines**: Must be refactored/split into smaller modules, unless explicit justification is documented.
- **Hard limit**: Business/feature implementation files must not exceed 1000 lines.
