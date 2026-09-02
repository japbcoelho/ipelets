# Conics for Ipe

[Leia em português](README.pt-BR.md)

Conics is a standalone Lua ipelet for constructing, fitting, classifying, intersecting, trimming, inspecting, and annotating conics. It supports ellipses, circles, parabolas, hyperbolas, and explicit degenerate loci. It keeps exact Ipe geometry where possible, uses compact adaptive splines for open hyperbola branches, and makes every visible result editable and undoable.

## Signature workflow: five points become a structured conic

Select five marks and choose `Conic through five points`. Conics solves the homogeneous five-point system directly, rejects duplicate, ill-conditioned, and degenerate data, classifies the result, and chooses its best Ipe representation automatically: a native ellipse, an exact quadratic parabola spline, or continuous adaptive cubic hyperbola branches.

Select the result and open `Property guides` to create its meaningful geometry—center or vertex, axes, vertices, foci, directrices, and asymptotes—using native marks, lines, and optional labels.

The directrix-and-foci workflow can create several exact parabolas in one operation while preserving one clean undo step.

Version 1.1 also works from the dual side of conic geometry: five tangent lines determine a conic, mixed point-and-tangent conditions can be combined, and an exterior point produces both tangents and their chord of contact. Two selected conics can be intersected directly, and an existing curve can be trimmed to a connected conic arc or fitted and replaced in one undoable transaction.

## Highlights

- One self-contained `conics.lua` runtime file.
- No companion Geometry ipelet, bridge, network access, or external Lua package required.
- Native exact ellipses and compact exact parabola splines.
- Continuous hyperbola branches subdivided by geometric error tolerance.
- Exact five-line dual construction and mixed point/tangent constraints.
- Least-squares fitting from 6–512 sample marks, with conditioning and residual checks.
- Poles, polars, exterior tangents, chords of contact, focal chords, and conic–conic intersections.
- Exact/adaptive conic arcs and transactional fit-and-replace for selected paths.
- Explicit line-pair, double-line, single-line, point, and empty degenerate loci.
- Latus recta, auxiliary/director circles, equations, area, and parameter labels.
- Strict selection, option, metadata, and finite-number validation.
- Automatic live preview plus a manual Preview button.
- Active-layer creation, safe use of the current Ipe attributes, grouping controls, and single-step undo/redo.
- Scale-aware calculations for very small and very large coordinates.
- Compatible reading of conic metadata written by the earlier Geometry implementation.

## Tools

The Ipe menu contains `Ipelets → Conics` with seven entries:

| Menu entry | Included workflows |
| --- | --- |
| Construct: conic | Steiner ellipses; exact five-point construction; best fit from many points; five tangent lines; five mixed point/tangent conditions; focus–directrix with a point or numeric eccentricity; canonical midpoint ellipse; and explicit degenerate loci. |
| Construct: ellipse | Native ellipse from two foci and one point, or from a center and two perpendicular semiaxis endpoints. |
| Construct: hyperbola | Hyperbola from two foci and a point, center and semiaxes, equal semiaxes, or two asymptotes and one point. |
| Construct: parabola | One exact parabola for every focus paired with a directrix, or one parabola from its vertex and focus. |
| Features: conic | Tangent/normal, polar and pole, tangents from a point, chord of contact, focal chord, line and conic intersections, conic arcs, fit-and-replace, and editable property/equation guides. |
| Inspect: conic | Compute coefficients and standard properties without changing the document. |
| Metadata: revalidate selected conic | Refit and replace stale metadata after structural path editing. |

## Requirements

- Ipe with Lua 5.4 ipelet support.
- Designed and tested for Ipe 7.2.30 on Linux.

The ipelet uses documented Ipe Lua objects and does not require a build step.

## Installation

Download the self-contained package from the [Conics 1.1.0 release](https://github.com/japbcoelho/ipelets/releases/tag/conics-v1.1.0), or use one of the methods below.

### Repository helper on Linux

From the repository root:

```bash
./scripts/install.sh conics
```

Restart Ipe after the copy completes.

### Manual installation

Copy [`conics.lua`](conics.lua) into one of Ipe's user ipelet directories:

- Linux, native installation: `~/.ipe/ipelets/`
- Linux, Flatpak installation: `~/.var/app/org.otfried.Ipe/.ipe/ipelets/`
- macOS: `~/.ipe/ipelets/` or `~/Library/Ipe/Ipelets/`
- Windows: `%USERPROFILE%\Ipelets\`

Place the file directly in the ipelet directory, restart Ipe, and open the new `Conics` submenu under `Ipelets`.

## Selection contracts

The dialogs show these requirements in the interface:

| Workflow | Required selection |
| --- | --- |
| Steiner ellipses | Exactly three marks. |
| Conic through five points | Exactly five marks. |
| Best-fit conic | From 6 to 512 marks. |
| Conic tangent to five lines | Exactly five segments. |
| Five mixed conditions | Five marks; or four marks plus one tangent segment; or three marks plus two tangent segments. Each tangent segment must pass through exactly one selected tangent-point mark. |
| Focus, directrix, and point | Two marks and one segment; the point on the conic must be primary, the other mark is the focus, and the segment is the directrix. |
| Focus, directrix, and eccentricity | One primary focus mark and one secondary directrix segment; enter `e<1`, `e=1`, or `e>1` for an ellipse, parabola, or hyperbola. |
| Canonical midpoint ellipse | Exactly four marks. |
| Ellipse from foci and point | Three marks; the point on the ellipse must be primary and the two secondary marks are the foci. |
| Ellipse from center and semiaxes | Three marks; the center must be primary and the two endpoints must define nonzero perpendicular semiaxes. |
| Hyperbola from foci and point | Three marks; the point on the hyperbola must be primary and the two secondary marks are the foci. |
| Hyperbola from parameters | One primary center mark and, optionally, one secondary segment supplying the transverse-axis direction. |
| Hyperbola from asymptotes and point | One primary point mark and two secondary segments defining intersecting asymptotes. |
| Parabola from directrix and foci | One primary directrix segment and one or more secondary focus marks. |
| Parabola from vertex and focus | Two marks; the vertex must be primary. |
| Degenerate loci | Two segments for a line pair, one segment for a double or single line, one mark for a point, and no selection for the empty locus. |
| Tangent, normal, or polar | One primary conic and one secondary mark. A tangent or normal point must lie on the conic. |
| Tangents from a point | One primary conic and one secondary mark; zero, one, or two real tangents are reported correctly. |
| Pole of a line | One primary conic and one secondary segment. A pole at infinity is reported without creating a false finite point. |
| Focal chord | One primary noncircular conic and one secondary mark defining the line through a selected focus. |
| Line intersections | One primary conic and one secondary segment. |
| Intersections of two conics | Exactly two conics; the first must be primary. Zero through four finite real intersections and coincident conics are distinguished. |
| Trim conic to arc | One primary conic and two secondary marks on the same connected arc. |
| Fit and replace selected path | Exactly one primary path. |
| Property guides, inspection, or revalidation | Exactly one primary conic or one group containing a single logical conic. |

Explicit API inputs take precedence over document selection. When a workflow must read the selection, extra or incorrectly typed selected objects are rejected instead of silently ignored.

## Extent, quality, and grouping

- `extent` sets a symmetric open-curve extent. For a hyperbola it is measured along the transverse axis and must exceed the transverse semiaxis.
- General conic construction also accepts `bounds={left,bottom,right,top}`. `extent` and `bounds` are mutually exclusive.
- `padding` expands an automatically inferred open-curve extent.
- `tolerance` controls the maximum geometric approximation error used to subdivide a hyperbola branch.
- `max_segments` is a safety budget for each adaptive hyperbola branch; the legacy `samples` alias remains accepted as a segment budget with a minimum of four.
- `expected_kind` can constrain a least-squares fit to `ellipse`, `parabola`, or `hyperbola`; the fit is rejected when its residual or conditioning is unreliable.
- `arc_mode` selects the shorter, longer, clockwise, or counterclockwise ellipse arc. Parabola and hyperbola endpoints must belong to one connected branch.
- `group_output` chooses whether related branches, auxiliaries, multiple parabolas, or multiple feature objects are grouped. If they remain separate, only the first object is primary and the rest are secondary selections.

## Analytic properties and equations

`Property guides` can create the applicable center or vertex, axes, vertices, foci, directrices, asymptotes, latus recta, auxiliary circles, and director circle. It can also place editable LaTeX labels for the normalized general equation, a canonical equation, and parameters such as `a`, `b`, `c`, eccentricity, focal parameter, semilatus rectum, focal radius, and ellipse area. Controls that do not apply to the selected operation are disabled in the dialog.

## Preview and document behavior

Live preview is enabled by default and never mutates the document. It follows dialog options and the selected objects' geometry and affine matrices. The manual Preview button reports a useful status or error in Ipe's status area. Canceling or an exception always removes the preview overlay and timer.

Objects are created on the active layer. Conics warns when that layer is invisible. Path, mark, and text attributes are derived from the current Ipe attributes, but incompatible path attributes such as fill, arrows, and decorations are filtered out. The ipelet does not require a personal stylesheet; every default symbolic name comes from Ipe's standard styles.

## Metadata and editing

Created curves use versioned `conics:v1` metadata with an object role, conic identifier, kind, source, coordinate space, coefficients, and a geometry fingerprint. Auxiliary axes, marks, labels, directrices, asymptotes, poles, chords, latus recta, auxiliary/director circles, equations, and degenerate loci have distinct roles and never masquerade as an ordinary conic curve.

Moving, rotating, scaling, or shearing a conic is supported: inspection transforms its stored coefficients by the object's affine matrix. Editing the internal nodes of an approximate path changes the geometry without changing that matrix, so Conics detects a stale fingerprint. Use `Metadata: revalidate selected conic` to refit the selected path; the command refuses a repair when the edited shape is not reliably conic.

## Examples

- [`conics-overview.ipe`](examples/conics-overview.ipe) is the editable presentation source for the five-point workflow, basic property extraction, focus-directrix construction, hyperbola branches, and multiple parabolas.
- [`conics-feature-gallery.ipe`](examples/conics-feature-gallery.ipe) is a 32-page editable gallery generated by the live acceptance audit. It covers every construction family, the advanced feature workflows, degenerate loci, previews, fitting, inspection, and metadata revalidation.
- Both example documents carry every style they need and remain the authoritative editable demonstrations of the workflows.

## Public API

`_G.CONICS` exposes API version `1`. The creators accept either selection-driven input or structured tables. For feature operations, prefer separate `definition` and `feature_input` blocks:

```lua
local result = CONICS.create_conic_features(model, {
  operation = "conic_intersections",
  definition = { coefficients = { 1, 0, 1, 0, 0, -100 } },
  feature_input = {
    second_coefficients = { 1, 0, 1, -12, 0, -64 },
  },
  marks = false,
})
```

This returns a computed result with two points and does not mutate the document. The canonical creator names are `create_conic`, `create_ellipse`, `create_hyperbola`, `create_parabola`, and `create_conic_features`; the 1.0 aliases `create_ellipse_from_foci` and `create_parabolas` remain available. Public creators consistently report `created`, `status`, `operation`, `element_count`, `object_count`, `metadata`, and `result`.

## Testing

From the repository root:

```bash
./scripts/validate.sh conics
```

The portable suite loads only `conics.lua` in a minimal Ipe-compatible Lua runtime. It covers construction contracts, numerical regressions, metadata migration and corruption, previews, transactions, package contents, and the absence of local development dependencies.

## Troubleshooting

### Conics does not appear

Confirm that `conics.lua` is directly inside an Ipe user ipelet directory, not inside a nested `conics/` folder, and restart Ipe completely.

### A selection is rejected

Check the `Required selection` line in the dialog. Point inputs must be `mark/*` references, and a line input must be one open path containing exactly one segment. Extra selected text, paths, or references are intentionally rejected.

### The object was created but is not visible

Conics uses the active layer. Make that layer visible or activate a visible layer before creating the result.

### Inspection says the metadata is stale

The curve's internal shape was edited. Use the revalidation command if the edited path is still a conic, or reconstruct it from its defining inputs.

## License and attribution

Copyright (C) 2026 japbcoelho. Conics is licensed under the GNU General Public License, version 3 or any later version. The ellipse-from-foci and parabola formulas are adapted from Ipe's GPL-licensed `goodies.lua`. See [LICENSE](../LICENSE) and [NOTICE.md](../NOTICE.md).
