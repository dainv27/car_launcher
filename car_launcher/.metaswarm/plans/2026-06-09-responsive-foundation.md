# Responsive Foundation Plan

## Scope

- Support automotive landscape displays from 1024x600 through 2560x1080.
- Preserve the 1920x720 reference design.
- Keep the native 80dp system sidebar reservation unchanged.

## Work Units

1. Add shared responsive breakpoints and spacing helpers.
2. Make Dashboard weather/media cards compact at narrow widths.
3. Make Media Center controls compact on short/narrow displays.
4. Replace the Settings category rail with a horizontal selector on narrow displays.
5. Add multi-viewport regression tests for all core screens.

## Validation

- Flutter widget tests at 1024x600, 1280x720, 1920x720, and 2560x1080.
- Android debug build.
- Emulator screenshots at compact and expanded sizes.
