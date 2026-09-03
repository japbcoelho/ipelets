# Vectors

[Leia em português](README.pt-BR.md)

Vectors is a standalone extension for the [Ipe drawing editor](https://ipe.otfried.org/) that decomposes vectors and constructs exact resultants and ordered differences. Installation uses one Lua file and does not depend on another user ipelet or on the local MCP bridge.

![Vector decomposition and arithmetic workflows](docs/images/01_vectors_overview.png)

## Tools

The ipelet adds four menu entries:

- **Create components in current axes** decomposes one selected arrowed segment in the active Ipe coordinate axes. If no custom axes are active, it uses the standard Cartesian axes.
- **Decompose into selected directions** decomposes one arrowed vector in two selected, nonparallel straight directions.
- **Create resultant from selected (auto)** sums two or more connected selected vectors and chooses a tail-to-tail, directed-polyline, or connected-sum layout automatically.
- **Subtract selected (auto)** computes the primary vector minus every remaining selected vector, in selection order.

The component dialog provides live geometric preview, a manual **Preview** action, editable label base, and `_1 / _2` or `_x / _y` labels. Final labels remain ordinary editable Ipe text objects.

## Visual guide

### Components in the current axes

The first command follows the coordinate system currently active in Ipe. With no custom axes it produces ordinary Cartesian components; with rotated axes it follows that orientation. Both components, both completion guides, and both labels are created in one undoable operation.

![Components in default and rotated Ipe axes](docs/images/02_components_in_current_axes.png)

### Components in selected directions

The selected directions may be oblique and a component may point opposite to its defining direction. A uniquely arrowed source is recognized even when a direction is primary. When all three selected segments are arrowed from a common tail, Vectors can also identify the unique source lying inside the positive cone of the other two.

![Positive and negative components in selected directions](docs/images/03_components_in_selected_directions.png)

### Automatic resultants

For two vectors, the command recognizes tail-to-tail and head-to-tail arrangements. With three or more vectors it handles a directed chain or any other connected endpoint graph. The red vectors in the guide are exact results created by the ipelet.

![Tail-to-tail, head-to-tail, chain, and connected resultants](docs/images/04_connected_resultants.png)

### Ordered subtraction

The primary selection is the minuend. Every remaining selected vector is subtracted in page selection order, so changing the primary selection changes the result without changing the source objects.

![Common-endpoint and ordered multi-vector subtraction](docs/images/05_ordered_subtraction.png)

### Physical application: weight on an inclined plane

Set the active x-axis down the slope and the active y-axis perpendicular into the plane, then select the vertical weight vector. The same current-axes command creates the exact down-slope and inward-normal components. The example keeps the gray inclined plane, light-gray block, center mark, weight, components, guides, and labels as editable Ipe objects.

![Weight decomposition on an inclined plane](docs/images/06_weight_on_inclined_plane.png)

## Accepted selections

A vector must be exactly one open straight path segment with exactly one arrow direction. Closed paths, curves, mixed paths, multiple subpaths, zero-length segments, paths without an arrowhead, and double-headed paths are rejected with a clear message.

For decomposition into selected directions, select exactly three objects. If exactly one has an arrowhead, it is the source vector even when another object is primary. If all three are arrowed from a common tail, Vectors uses the unique segment that has two positive components in the other directions when such a segment exists. Otherwise, make the source vector primary. The remaining two objects determine direction 1 and direction 2 in page selection order and may be plain straight segments.

For resultants and subtraction, select at least two arrowed vectors whose endpoints form one connected graph. A two-vector resultant requires tail-to-tail or head-to-tail contact; a head-to-head pair is deliberately rejected because it does not define either supported resultant layout. Subtraction accepts every shared-endpoint orientation. The primary selection is processed first: it anchors a non-chain connected resultant and is always the subtraction minuend. Remaining operands follow page selection order. `touch_tolerance` is used only to recognize endpoint contact; it never modifies a source vector or the resulting sum or difference.

Corrected arrow groups created by ArrowFix are accepted. Explicit numeric widths and arrow sizes remain numeric, and explicit RGB strokes remain colors rather than becoming unresolved symbolic names.

## Output and styles

Components, guides, labels, resultants, and differences are created as loose editable objects. A component construction is registered as one atomic Ipe transaction, so one Undo action removes the complete result. Components are dashed, guides are dotted, and generated vectors always remain stroked with one forward arrowhead.

Source vector styling is inherited where meaningful. Public attribute overrides are allowlisted and validated against the active style sheet before object creation. Invalid colors, unknown attributes, unsupported path modes, malformed booleans, missing symbolic styles, and non-finite numeric inputs are rejected rather than passed to Ipe.

Every generated object receives escaped custom metadata with its role and source selection indexes. Those indexes describe the document at creation time; moving or deleting earlier objects later does not rewrite historical metadata.

## Installation

Download the self-contained package from the [Vectors 1.0.0 release](https://github.com/japbcoelho/ipelets/releases/tag/vectors-v1.0.0), or install it from the repository.

From the repository root on Linux:

```bash
./scripts/install.sh vectors
```

The helper detects the Ipe Flatpak directory. For a manual installation, place `vectors.lua` in the user ipelets directory and restart or reload Ipelets in Ipe.

## Public API

The file exports `_G.VECTORS` with API version 1. Pure geometry helpers can be used without creating Ipe objects:

```lua
local components = VECTORS.components_in_directions(
  { x = 30, y = 40 },
  { x = 1, y = 0 },
  { x = 1, y = 1 }
)
assert(math.abs(components.first_scalar + 10) < 1e-9)
```

The public creators are `create_selected_vector_components`, `create_selected_vector_components_in_directions`, `create_selected_vector_resultant_auto`, and `create_selected_vector_subtraction_auto`. They validate the complete input before registration and return stable result tables containing creation counts, source indexes, modes, contacts, scalars, and exact result vectors.

## Validation

Run the focused suite with:

```bash
./scripts/validate.sh vectors
```

The suite checks syntax, geometry, topology, scale extremes, ArrowFix compatibility, strict paths and options, atomic undo, metadata, previews, performance, packaging, and standalone runtime isolation.

The editable 13-page workflow source, the separate inclined-plane application, and details about all six presentation boards are in [`examples/`](examples/README.md). Release history is in [`CHANGELOG.md`](CHANGELOG.md).

## License

Vectors is licensed under the GNU General Public License, version 3 or any later version. See the repository [LICENSE](../LICENSE) and [NOTICE](../NOTICE.md).
