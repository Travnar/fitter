# Fitter

## Code Architecture
- Logic goes in `Controllers/`.
- Interface goes in `Views/`.
- Constants and definitions go in `Data/`.
- Interface strings go in `Localizations/`, one file per locale (`enUS.lua` is the base).
- Assets go in `Assets/`.
- Design docs go in `Docs/`.
- When a file approaches 500 lines, consider refactoring it into separate files. Prompt the user to get confirmation on planned refactor changes. 

## Design Principles
- Use default World of Warcraft Forever UI elements where possible instead of custom builds or look-alikes.
- Do not assume important decisions. Ask first.
