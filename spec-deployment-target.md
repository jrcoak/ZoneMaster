# Update Deployment Target to macOS 26.0 (Tahoe)

## Problem Statement

The project was originally configured for macOS 13.0 (Ventura) but uses APIs that require macOS 14.0+, causing build errors. The user wants to target macOS 26.0 (Tahoe) instead, eliminating all compatibility concerns and enabling use of the latest SwiftUI and system APIs.

## Requirements

- **R1** Update `MACOSX_DEPLOYMENT_TARGET` from `13.0` to `26.0` in the Xcode project (both Debug and Release, both project-level and target-level build settings).
- **R2** Update `LSMinimumSystemVersion` in `Info.plist` from `13.0` to `26.0`.
- **R3** No code changes needed — all existing APIs (`.onChange` two-param, `.onKeyPress`, `.formStyle(.grouped)`) are available on macOS 26.0.

## Acceptance Criteria

1. Project builds without deployment target warnings or availability errors when targeting macOS 26.0.
2. `MACOSX_DEPLOYMENT_TARGET` is `26.0` in all four build configuration entries in `project.pbxproj`.
3. `Info.plist` `LSMinimumSystemVersion` is `26.0`.

## Implementation Approach

1. Update `MACOSX_DEPLOYMENT_TARGET` in `project.pbxproj` (4 occurrences: Debug/Release × project/target)
2. Update `LSMinimumSystemVersion` in `Info.plist`
3. Commit and push
