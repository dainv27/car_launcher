# Plan: App Drawer Code Refactor for Maintainability

## Goal
Refactor the app drawer implementation to improve code maintainability, readability, and adherence to Flutter best practices while preserving all existing functionality.

## Specific Refactoring Tasks

### 1. App Drawer Page Refactor
- Break down the large `build()` method in `_AppDrawerPageState` into smaller, focused methods
- Extract the background glow positioning logic into a separate widget
- Extract the app grid configuration into a separate method or class
- Improve separation of concerns between UI construction and state management

### 2. AppsGridLayout Class Refactor
- Extract the complex layout resolution logic into smaller, well-named helper methods
- Add documentation comments explaining the layout algorithm
- Consider breaking the `resolve` method into phases: calculate dimensions, determine grid specs, calculate cell properties
- Add unit tests for the layout calculation logic

### 3. AppIconTile Refactor
- Extract the icon loading and placeholder logic into separate methods
- Consider creating a separate state class for the icon loading states
- Improve the readability of the build method by extracting widget construction

### 4. Code Quality Improvements
- Add missing documentation comments for complex algorithms
- Ensure consistent naming conventions
- Remove any redundant code or comments
- Verify all constants are properly named and grouped

## Implementation Approach
1. Create widget tests to ensure visual regression doesn't occur
2. Refactor incrementally, ensuring tests pass after each change
3. Run flutter analyze to ensure no lint issues are introduced
4. Verify functionality manually on emulator/device

## Files to Modify
- lib/features/app_drawer/presentation/app_drawer_page.dart
- lib/features/app_drawer/presentation/widgets/apps_grid_layout.dart
- lib/features/app_drawer/presentation/widgets/app_icon_tile.dart
- lib/features/app_drawer/presentation/widgets/app_icon_image.dart (if needed)
- test/ (add/update widget tests as needed)

## Success Criteria
- All existing tests pass
- No visual changes to the UI (pixel-perfect preservation)
- Improved code readability and maintainability
- Reduced complexity in large methods
- Better separation of concerns
- No new lint warnings or errors