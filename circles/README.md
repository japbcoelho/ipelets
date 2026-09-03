# Circles for Ipe

[Leia em português](README.pt-BR.md)

Circles is a standalone Lua ipelet for exact and practical circle geometry. It combines construction dialogs, live canvas previews, stable analytic solvers, undo-aware output, and editable native Ipe objects in one file.

## Signature workflow: choose a tangent circle

Select three circles, open `Construct: tangent circle`, choose the three-circle constraint set, and set `Circle tangency` to `All`. The circles can have different radii and do not need to be symmetrically placed. Circles computes all eight exact candidates and displays them directly on the canvas.

The red outlines in the first panel are the eight valid solutions. Moving the pointer changes the active candidate, shown with a double outline. Click that candidate to create only the selected circle; optional tangency marks and radius guides remain native, editable Ipe objects.

![All eight tangent-circle candidates and the selected editable result](docs/images/01_all_tangent_circle_candidates.png)

## Visual guide

The gallery deliberately omits basic circle and arc constructions already available in Ipe. It concentrates on the operations that add a distinct workflow or expose several geometric solutions.

### Inversion and radical constructions

The six panels show point, line, and circle inversion; the radical axis of two circles; the radical center of three circles; and a circle orthogonal to a reference circle. Dashed dark-blue objects are inputs, while black objects are the results created by the ipelet.

![Six inversion and radical constructions](docs/images/02_inversion_and_radicals.png)

### Tangent lines

Tangents can be constructed from a point to a circle, between two circles, or parallel or perpendicular to a selected line. The common-tangent workflow can return all four tangents or only the external or internal pair. Black dots identify contact points.

![Tangent-line operations and their contact points](docs/images/03_tangent_lines.png)

### Tangent-circle constraint sets

Each operation combines three constraints chosen from circles, points, and lines. The dialog can expose every valid candidate; the gallery shows one selected result for each constraint set, while the signature workflow above expands the three-circle case to all eight candidates.

![Eight tangent-circle constraint sets](docs/images/04_tangent_circle_constraints.png)

### Center of a transformed ellipse

For an affine-transformed ellipse, the command inserts its geometric center as an editable mark. Circle and circular-arc center examples are intentionally omitted because Ipe already provides those centers directly.

![Center marked on a transformed ellipse](docs/images/05_mark_ellipse_center.png)

## Highlights

- One self-contained `circles.lua` file.
- No Geometry ipelet, companion bridge, network access, or external Lua package required.
- Interactive tangent-circle chooser with all exact candidates visible at once.
- Native editable Ipe paths, marks, labels, and groups.
- Automatic live preview plus a manual Preview button.
- Explicit validation and useful error messages for invalid selections.
- Numerical safeguards for very small and very large coordinate scales.

## Tools

The Ipe menu contains `Ipelets → Circles` with five entries:

| Menu entry | Included workflows |
| --- | --- |
| Construct: circle | Center and point, center and radius, diameter, three points, three-point arc, two points and radius, polar line, pole of a line, and homothety centers. |
| Construct: tangent circle | Three circles; two circles and a point or line; two points and a circle or line; point-line-circle; two lines and a circle or point; and three lines. |
| Construct: tangent lines | From a point to a circle, common circle tangents, and lines parallel or perpendicular to a reference line. |
| Inversion/radicals: operations | Invert a point, line, or circle; radical axis; radical center; and orthogonal circle. |
| Mark center: circle/ellipse/arc | Mark the transformed center of the selected circle, ellipse, or circular arc. |

## Requirements

- Ipe with Lua ipelet support.
- Verified with Ipe 7.2.30 and Lua 5.4 on Linux.

The ipelet uses documented Ipe Lua objects and does not require a separate build step.

## Installation

Download the self-contained package from the [Circles 1.0.1 release](https://github.com/japbcoelho/ipelets/releases/tag/circles-v1.0.1), or use one of the methods below.

### Repository helper on Linux

From the repository root:

```bash
./scripts/install.sh circles
```

Restart Ipe after the copy completes.

### Manual installation

Copy [`circles.lua`](circles.lua) into one of Ipe's user ipelet directories:

- Linux, native installation: `~/.ipe/ipelets/`
- Linux, Flatpak installation: `~/.var/app/org.otfried.Ipe/.ipe/ipelets/`
- macOS: `~/.ipe/ipelets/` or `~/Library/Ipe/Ipelets/`
- Windows: `%USERPROFILE%\Ipelets\`

Create the directory if necessary, copy the file, and restart Ipe. The new `Circles` submenu appears under `Ipelets`.

## Basic use

1. Draw or select the input objects requested by a tool. The dialog states the required selection.
2. Open `Ipelets → Circles` and choose a workflow.
3. Adjust the construction options while watching the live preview.
4. Choose Create. The result remains editable and can be undone normally.

The primary selection matters in operations that distinguish one input, such as circle inversion. The dialog describes that ordering where necessary.

## Preview behavior

Live preview is enabled by default and does not modify the document. It updates as dialog fields change. Disable the checkbox for a quieter workflow or use the Preview button for an explicit refresh. Canceling a dialog removes the preview overlay without creating objects.

## Examples

- [`circles-overview.ipe`](examples/circles-overview.ipe) is the 23-page editable source behind all five boards. It contains the eight-candidate preview, the selected result with tangency guides, every inversion/radical and tangent-line panel, all eight remaining tangent-circle constraint sets, and the transformed-ellipse center example.
- Every diagram was generated and rendered in a real Ipe 7.2.30 session. The presentation boards contain those Ipe renders rather than substitute vector illustrations.

## Shortcut

`Alt+T` opens the third Circles method, `Construct: tangent lines`, when that key combination is available in the current Ipe configuration.

## Testing

From the repository root:

```bash
./scripts/validate.sh
```

The test suite runs without external automation services. It exercises the analytic geometry, object-construction contracts, numerical regressions, explicit-input isolation, and release-source boundaries.

## Troubleshooting

### Circles does not appear

Confirm that `circles.lua` is directly inside an Ipe user ipelet directory, not inside a nested `circles/` directory, then fully restart Ipe.

### A construction reports an invalid selection

Check the required-selection line in the dialog. Marks supply points, path ellipses supply circles, and a straight single-segment path supplies a line constraint.

### The created object is not visible

Circles creates output on the active layer. Make that layer visible or activate a visible layer before creating the construction.

## License

Copyright (C) 2026 japbcoelho. Circles is licensed under the GNU General Public License, version 3 or any later version. See the repository [LICENSE](../LICENSE).
