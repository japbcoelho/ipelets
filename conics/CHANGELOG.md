# Changelog

All notable changes to Conics are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow semantic versioning.

## [Unreleased]

## [1.1.0] - 2026-08-29

### Added

- Least-squares conic fitting from 6–512 sample marks, with expected-kind, conditioning, and residual diagnostics.
- Dual construction from five tangent lines and mixed systems containing five weighted point/tangent conditions.
- Focus–directrix construction from an explicit eccentricity, covering ellipses, parabolas, and hyperbolas through one workflow.
- Native ellipse construction from a center and two perpendicular semiaxis endpoints.
- Parabola construction from vertex and focus, plus hyperbola construction from two asymptotes and one point.
- Explicit intersecting-line, parallel-line, double-line, single-line, point, and empty degenerate conic loci.
- Tangents from an arbitrary point, chord of contact, pole of a line, and focal chord operations.
- Robust conic–conic intersections with zero through four finite real points and coincident-conic reporting.
- Exact/adaptive conic arcs and transactional fit-and-replace for a selected path.
- Latus recta, auxiliary circles, director circles, general/canonical equations, parameter labels, focal radius, semilatus rectum, and ellipse area.
- Canonical `create_ellipse` and `create_parabola` API names while preserving the 1.0 aliases.

### Changed

- Renamed the public menu entries to `Construct: ellipse` and `Construct: parabola` because each dialog now provides multiple constructions.
- Expanded every construction and feature dialog with contextual controls, exact selection guidance, persistent successful settings, and live preview.
- Extended metadata roles and fingerprints to cover conic arcs, degenerate loci, poles, chords, equations, and circular guides.
- Revalidation now uses the many-point least-squares fitter instead of choosing only five path samples.
- Conic–conic elimination now uses a normalized coordinate frame and both coordinate orientations for improved scale and tangency stability.
- Finite polar and contact-chord segments are anchored near their defining geometry instead of an arbitrary coordinate-axis intercept.

### Compatibility

- Lua API version remains `1`; all version 1.0 creator names and action aliases remain accepted.
- Existing `conics:v1` and supported legacy Geometry metadata remain readable.
- The installed runtime remains one standalone `conics.lua` file and does not depend on Geometry, MCP, a personal stylesheet, the network, or an external Lua package.

### Verified

- Added behavior tests for every new constructor and feature, noisy fitting, degenerate classifications, numerical scale stress, transactional replacement, invalid input, and package sanitization.
- Added a 32-page editable acceptance gallery plus README media rendered from the live Ipe audit.

## [1.0.0] - 2026-08-29

### Added

- Four general conic constructions: Steiner ellipses, a conic through five points, focus-directrix-point, and the canonical midpoint ellipse of a quadrilateral.
- Dedicated ellipse-from-foci, hyperbola, and directrix-with-foci parabola workflows.
- Tangent, normal, polar, line-intersection, property-guide, inspection, and metadata-revalidation tools.
- Automatic live preview and a manual Preview button for every construction dialog.
- Classification and extraction of centers, vertices, axes, foci, directrices, eccentricity, and asymptotes.
- A versioned public Lua API and a strict, role-aware `conics:v1` metadata format.

### Changed

- Prepared Conics as a self-contained single-file ipelet with no Geometry runtime dependency.
- Replaced fragmented implicit rendering with native ellipses, exact quadratic parabola splines, and adaptive continuous cubic hyperbola branches.
- Added scale-aware tolerances, stable quadratic roots, scaled norms, a direct null-space solver for five-point fitting, and finite-output validation.
- Made explicit inputs authoritative and selection contracts strict and visible in the dialogs.
- Preserved active Ipe attributes safely, standardized creation on the active layer, and made grouping explicit.

### Compatibility

- Affine transformations preserve conic coefficients.
- Existing `geometry:conic` and `geometry:hyperbola` metadata remain readable.
- Structural path edits are detected as stale metadata and can be revalidated from the selected curve.

### Verified

- Added standalone behavioral, numerical, package, and release-contract suites for Lua 5.4.

[Unreleased]: https://github.com/japbcoelho/ipelets/compare/conics-v1.1.0...HEAD
[1.1.0]: https://github.com/japbcoelho/ipelets/releases/tag/conics-v1.1.0
