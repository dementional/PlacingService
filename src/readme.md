<img width="1920" height="480" alt="Banner" src="https://github.com/user-attachments/assets/d662f4dc-5ba7-4d09-aaa1-4e7d676de4c8" />

# PlacingService

A client-side module for Roblox that handles object previewing, grid snapping, rotation, and placement validation.

---

---

## Quick Start

```lua
local PlacingService = require(script.PlacingService)

-- // Start a preview
local part: Part = workspace.SomePart
PlacingService.SetPreview(part)

-- // Cancel it
PlacingService.Cancel()

-- // Rotate on Y axis
PlacingService.Rotate(Vector3.yAxis)
```

---

## API

### `PlacingService.SetPreview(instance: BasePart | Model)`
Starts a live preview bound to `RenderStep`. Automatically cancels any existing preview.

### `PlacingService.Cancel()`
Cancels and destroys the current preview, resetting all internal state.

### `PlacingService.Rotate(axis: Vector3)`
Rotates the preview by `RotationUnit` degrees around the given axis.

### `PlacingService.GetPreview(): Instance?`
Returns the current preview instance, or `nil` if none is active.

### `PlacingService.GetTargetCF(): CFrame?`
Returns the snapped `CFrame` the preview would be placed at based on the current mouse position.

---

## Signals

| Signal | Args | Description |
| --- | --- | --- |
| `PlacementStarted` | — | Fires when a preview begins |
| `PlacementEnded` | — | Fires when a preview is cancelled |
| `Rendered` | `preview: Instance, targetCF: CFrame, canPlace: boolean` | Fires every `RenderStep` while a preview is active |

---

## Settings

| Property | Type | Description | Default |
| --- | --- | --- | --- |
| `CanOverlapWithOtherParts` | `boolean` | Allow placement when colliding with other parts | `false` |
| `CanPlaceColor` | `Color3` | Highlight color when placement is valid | `Color3.fromRGB(255, 255, 255)` |
| `CannotPlaceColor` | `Color3` | Highlight color when placement is invalid | `Color3.fromRGB(255, 165, 0)` |
| `GridUnit` | `number` | Grid snapping size | `1` |
| `RotationUnit` | `number` | Degrees per rotation step | `15` |
| `LerpSpeed` | `number` | How smoothly the preview follows the cursor | `25` |
| `RotateY` | `Enum.KeyCode` | Key to rotate the preview | `Enum.KeyCode.R` |
| `Cancel` | `Enum.KeyCode` | Key to cancel the preview | `Enum.KeyCode.X` |
