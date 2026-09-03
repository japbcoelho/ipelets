# Changelog

All notable changes to Triangles are documented in this file.

## [1.0.0] - 2026-08-30

### Added

- Standalone single-file runtime with a versioned `_G.TRIANGLES` API.
- Twenty-four individually selectable triangle centers and four mathematically grouped presets.
- Medial, orthic, contact, excentral, pedal, nine-point, cevian, isogonal, and isotomic constructions.
- Reference-point input from a selected mark, a known center, or explicit coordinates.
- Scale-normalized calculations, relative tolerances, finite-result validation, and explicit unavailable-center states.
- Selection from one closed triangular path, three vertex marks, or three side segments.
- Live preview driven by the same construction plan as the final output.
- Active Ipe attributes, active/source-layer selection, grouped output, and one-primary-selection transactions.
- Versioned per-object metadata with roles, full-precision source vertices, and geometry fingerprints.
- Deterministic vertex ordering without helper marks, semantic labels with text-size-aware geometry placement, and coincident-center consolidation.
- Center-specific defining lines, a dedicated nine-point-circle option, and descriptive names for the first and second isogonic centers.
- A seven-page editable Ipe gallery with semithick source triangles, normal-weight
  construction segments, and a real-Ipelib save/reopen integration test.

### Removed

- Runtime dependence on the hidden Geometry ipelet and local MCP bridge state.
- Implicit use of the centroid for point-dependent constructions.
- Duplicate preview geometry, fixed black output styling, and multiple primary selections.
- The public inspector menu entry, generic auxiliary lines, and duplicate incircle/excircle controls in the center dialog.
