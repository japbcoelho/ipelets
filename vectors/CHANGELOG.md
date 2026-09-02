# Changelog

All notable changes to Vectors are documented in this file.

## [1.0.0] - 2026-09-02

### Added

- Standalone single-file runtime with a versioned `_G.VECTORS` API.
- Decomposition in the current Ipe axes or in two selected directions.
- Automatic resultant construction for two or more connected vectors.
- Ordered subtraction with the primary selection as the minuend.
- Live geometric preview and explicit component-label preview.
- Compatibility with corrected ArrowFix groups, including typed numeric and RGB style recovery.
- Versioned, escaped metadata on every generated object.
- Atomic multi-object creation in one undo step.
- Two editable Ipe examples and six PNG presentation boards generated from real Ipelet output, including weight decomposition on an inclined plane.

### Fixed

- Endpoint tolerance no longer changes the exact sum or difference of source vectors.
- Connected-chain analysis no longer degrades cubically with reverse primary selections.
- Mixed, closed, curved, multi-subpath, zero-length, and double-headed vector inputs are rejected.
- Large finite direction vectors use a scaled norm instead of overflowing during normalization.
- Nested path attributes, colors, booleans, enumerations, and symbolic styles are validated.
- Math-delimited label bases no longer produce malformed LaTeX.
- Metadata delimiters are escaped and metadata write failures are no longer hidden.
- Preview and menu errors omit internal Lua source locations.
- Preview implementation details no longer leak into the shared Ipelet Lua namespace.
- Public menu labels no longer repeat the redundant `Vector:` prefix.
- Documentation now describes geometric source inference, pair-contact rules, and primary-selection ordering precisely.
