# Changelog

All notable changes to Circles are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow semantic versioning.

## [Unreleased]

## [1.0.0] - 2026-08-29

### Added

- Nine circle-construction workflows.
- Point-to-circle, circle-to-circle, and circle-to-line tangent workflows.
- Nine families of tangent-circle constraints with candidate selection.
- Point, line, and circle inversion operations.
- Radical-axis, radical-center, orthogonal-circle, pole, polar, and homothety constructions.
- Center marking for circles, ellipses, and arcs.
- Automatic live preview and an explicit Preview button in every construction dialog.
- Persistent dialog choices during the Ipe session.
- Undo-aware object creation and warnings for invisible active layers.
- Standalone public Lua API for advanced local integrations.

### Changed

- Prepared a clean single-file distribution independent of Geometry and external bridge code.
- Organized the visible menu into five concise workflows.
- Added scale-aware numerical tolerances and stable tangent-circle candidate filtering.
- Rebuilt the publication visuals around the interactive eight-candidate tangent-circle workflow and removed the personal styles from the editable example.

### Verified

- Tested with Ipe 7.2.30 and Lua 5.4 on Linux.
- Added independent geometry and regression suites.

[Unreleased]: https://github.com/japbcoelho/ipelets/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/japbcoelho/ipelets/releases/tag/v1.0.0
