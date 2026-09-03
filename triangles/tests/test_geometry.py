import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRIANGLES = ROOT / "triangles.lua"
RUNTIME = ROOT / "tests/triangles_runtime.lua"


class TrianglesContractTest(unittest.TestCase):
    maxDiff = None

    def run_lua(self, body: str) -> subprocess.CompletedProcess[str]:
        script = (
            f"TRIANGLES_PATH={json.dumps(str(TRIANGLES))}\n"
            + RUNTIME.read_text(encoding="utf-8")
            + "\n"
            + body
        )
        return subprocess.run(
            ["lua5.4", "-e", script],
            check=False,
            text=True,
            capture_output=True,
        )

    def assert_lua_passes(self, body: str) -> None:
        completed = self.run_lua(body)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_standalone_api_surface_and_product_isolation(self) -> None:
        self.assert_lua_passes(r'''
assert(_G.GEOMETRY == nil)
assert(_G.GEOMETRY_DIALOGS == nil)
assert(_G.IPE_MCP_BRIDGE_STATE == nil)
assert(api.api_version == 1)
assert(api.version == "1.0.0")
assert(api.is_compatible(1) == true)
assert(api.is_compatible(2) == false)
for _, name in ipairs(api.required_functions) do assert(type(api[name]) == "function", name) end
assert(type(_G.TRIANGLES_DIALOGS) == "table")
assert(#api.center_definitions == 24)
assert(#api.derived_definitions == 9)
assert(#methods == 2)
assert(methods[1].label == "Construct: triangle centers")
assert(methods[2].label == "Construct: derived triangle geometry")
''')

    def test_classic_centers_have_expected_coordinates(self) -> None:
        self.assert_lua_passes(r'''
local result = api.triangle_centers(
  { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 0, y = 3 },
  { "centroid", "incenter", "circumcenter", "orthocenter", "nine_point_center" }
)
local expected = {
  centroid = { 4 / 3, 1 },
  incenter = { 1, 1 },
  circumcenter = { 2, 1.5 },
  orthocenter = { 0, 0 },
  nine_point_center = { 1, 0.75 },
}
for name, point in pairs(expected) do
  assert(result.states[name].status == "finite", name)
  assert(approximate(result.points[name].x, point[1], 1e-11), name .. ".x")
  assert(approximate(result.points[name].y, point[2], 1e-11), name .. ".y")
end
''')

    def test_all_centers_are_scale_invariant_across_extreme_finite_scales(self) -> None:
        self.assert_lua_passes(r'''
local base_points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } }
local base = api.triangle_centers(base_points[1], base_points[2], base_points[3])
local finite_count = 0
for _, state in pairs(base.states) do if state.status == "finite" then finite_count = finite_count + 1 end end
assert(finite_count == 24)

for _, factor in ipairs({ 1e-200, 1e-100, 1e-12, 1, 1e12, 1e100, 1e200 }) do
  local points = {
    { x = 0, y = 0 }, { x = 4 * factor, y = 0 }, { x = factor, y = 3 * factor },
  }
  local scaled = api.triangle_centers(points[1], points[2], points[3])
  for name, state in pairs(base.states) do
    assert(scaled.states[name].status == state.status,
      name .. " status at scale " .. tostring(factor) .. ": " .. scaled.states[name].status)
    if state.status == "finite" then
      assert(approximate(scaled.points[name].x / factor, base.points[name].x, 2e-9), name .. ".x")
      assert(approximate(scaled.points[name].y / factor, base.points[name].y, 2e-9), name .. ".y")
    end
  end
end
''')

    def test_randomized_center_identities_hold(self) -> None:
        self.assert_lua_passes(r'''
math.randomseed(20260830)
local checks = 0
local function close_point(first, second)
  return approximate(first.x, second.x, 2e-8) and approximate(first.y, second.y, 2e-8)
end
local function complement(first, centroid)
  return { x = 3 * centroid.x / 2 - first.x / 2, y = 3 * centroid.y / 2 - first.y / 2 }
end
for _ = 1, 1000 do
  local a = { x = math.random() * 20 - 10, y = math.random() * 20 - 10 }
  local b = { x = math.random() * 20 - 10, y = math.random() * 20 - 10 }
  local c = { x = math.random() * 20 - 10, y = math.random() * 20 - 10 }
  local area = math.abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
  if area > 0.2 then
    local centers = api.triangle_centers(a, b, c).points
    assert(close_point(api.isogonal_conjugate(a, b, c, centers.centroid), centers.symmedian_point)); checks = checks + 1
    assert(close_point(api.isotomic_conjugate(a, b, c, centers.gergonne_point), centers.nagel_point)); checks = checks + 1
    assert(close_point(complement(centers.gergonne_point, centers.centroid), centers.mittenpunkt)); checks = checks + 1
    assert(close_point(complement(centers.incenter, centers.centroid), centers.spieker_center)); checks = checks + 1
    assert(close_point(api.isogonal_conjugate(a, b, c, centers.first_isodynamic), centers.first_fermat)); checks = checks + 1
    assert(close_point(api.isogonal_conjugate(a, b, c, centers.second_isodynamic), centers.second_fermat)); checks = checks + 1
    local expected = {
      x = 2 * centers.circumcenter.x - centers.orthocenter.x,
      y = 2 * centers.circumcenter.y - centers.orthocenter.y,
    }
    assert(close_point(expected, centers.de_longchamps)); checks = checks + 1
  end
end
assert(checks > 6500, tostring(checks))
''')

    def test_special_triangles_report_unavailable_and_coincident_centers(self) -> None:
        self.assert_lua_passes(r'''
local h = math.sqrt(3)
local pure = api.triangle_centers({ x = 0, y = 0 }, { x = 2, y = 0 }, { x = 1, y = h })
assert(pure.states.feuerbach_point.status == "undefined")
assert(pure.states.second_fermat.status ~= "finite")
assert(pure.states.second_isodynamic.status ~= "finite")

local model = new_model()
local created = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 2, y = 0 }, { x = 1, y = h } },
  centers = "all_centers", marks = true, labels = false,
})
assert(created.created == true, created.error)
assert(created.element_count < created.center_count)
local found_overlap = false
for _, issue in ipairs(created.result.issues) do
  if issue.category == "overlap" then found_overlap = true end
end
assert(found_overlap)
''')

    def test_named_advanced_centers_satisfy_geometric_characterizations(self) -> None:
        self.assert_lua_passes(r'''
local a, b, c = { x = 0, y = 0 }, { x = 7, y = 0 }, { x = 2, y = 5 }
local centers = api.triangle_centers(a, b, c).points
local function vector(first, second)
  return { x = first.x - second.x, y = first.y - second.y }
end
local function cross(first, second)
  return first.x * second.y - first.y * second.x
end
local function dot(first, second)
  return first.x * second.x + first.y * second.y
end
local function length(value)
  return math.sqrt(dot(value, value))
end
local function distance(first, second)
  return length(vector(first, second))
end
local function angle(first, second)
  return math.atan(math.abs(cross(first, second)), dot(first, second))
end
local function point_line_distance(point, first, second)
  return math.abs(cross(vector(second, first), vector(point, first)))
    / distance(first, second)
end

local first_brocard = centers.first_brocard
local omega = angle(vector(first_brocard, a), vector(b, a))
assert(approximate(omega, angle(vector(first_brocard, b), vector(c, b)), 1e-10))
assert(approximate(omega, angle(vector(first_brocard, c), vector(a, c)), 1e-10))
local second_brocard = centers.second_brocard
omega = angle(vector(second_brocard, a), vector(c, a))
assert(approximate(omega, angle(vector(second_brocard, c), vector(b, c)), 1e-10))
assert(approximate(omega, angle(vector(second_brocard, b), vector(a, b)), 1e-10))

local function rotated(value, radians)
  return {
    x = math.cos(radians) * value.x - math.sin(radians) * value.y,
    y = math.sin(radians) * value.x + math.cos(radians) * value.y,
  }
end
local function equilateral_third(first, second, radians)
  local offset = rotated(vector(second, first), radians)
  return { x = first.x + offset.x, y = first.y + offset.y }
end
local function centroid(first, second, third)
  return {
    x = (first.x + second.x + third.x) / 3,
    y = (first.y + second.y + third.y) / 3,
  }
end
local function assert_napoleon(name, radians)
  local point = centers[name]
  local opposite_a = centroid(b, c, equilateral_third(b, c, radians))
  local opposite_b = centroid(c, a, equilateral_third(c, a, radians))
  local opposite_c = centroid(a, b, equilateral_third(a, b, radians))
  assert(math.abs(cross(vector(point, a), vector(opposite_a, a))) < 1e-10)
  assert(math.abs(cross(vector(point, b), vector(opposite_b, b))) < 1e-10)
  assert(math.abs(cross(vector(point, c), vector(opposite_c, c))) < 1e-10)
end
assert_napoleon("first_napoleon", -math.pi / 3)
assert_napoleon("second_napoleon", math.pi / 3)

for _, name in ipairs({ "excenter_a", "excenter_b", "excenter_c" }) do
  local point = centers[name]
  local first = point_line_distance(point, b, c)
  assert(approximate(first, point_line_distance(point, c, a), 1e-10))
  assert(approximate(first, point_line_distance(point, a, b), 1e-10))
end

local incircle = api.triangle_contact_points(a, b, c, "incircle").circle
local circumradius = distance(centers.circumcenter, a)
assert(approximate(distance(centers.feuerbach_point, centers.incenter),
  incircle.radius, 1e-10))
assert(approximate(distance(centers.feuerbach_point, centers.nine_point_center),
  circumradius / 2, 1e-10))
assert(math.abs(cross(
  vector(centers.incenter, centers.nine_point_center),
  vector(centers.feuerbach_point, centers.nine_point_center))) < 1e-10)
assert(math.abs(cross(
  vector(centers.orthocenter, centers.circumcenter),
  vector(centers.exeter_point, centers.circumcenter))) < 1e-10)
''')

    def test_derived_point_operations_require_and_use_a_real_reference(self) -> None:
        self.assert_lua_passes(r'''
local a, b, c = { x = 0, y = 0 }, { x = 6, y = 0 }, { x = 1, y = 4 }
for _, operation in ipairs({
  "pedal_triangle", "cevian_endpoints", "isogonal_conjugate", "isotomic_conjugate",
}) do
  local ok, message = pcall(api.triangle_derived_points, a, b, c, { operation = operation })
  assert(ok == false)
  assert_contains(tostring(message), "requires point or point_center")
end

local point = { x = 2.2, y = 1.1 }
local pedal = api.triangle_derived_points(a, b, c, {
  operation = "pedal_triangle", point = point,
})
assert(pedal.status == "finite" and #pedal.points == 3)
assert(approximate(pedal.reference_point.x, point.x))
local isogonal = api.triangle_derived_points(a, b, c, {
  operation = "isogonal_conjugate", point = point,
})
assert(isogonal.status == "finite" and #isogonal.points == 1)
assert(not approximate(isogonal.points[1].x, api.triangle_center(a, b, c, "symmedian_point").point.x, 1e-4))
''')

    def test_public_creators_contain_errors_and_validate_nested_schemas(self) -> None:
        self.assert_lua_passes(r'''
for _, call in ipairs({
  function() return api.create_triangle_centers(new_model(), true) end,
  function() return api.create_triangle_derived(new_model(), "bad") end,
  function() return api.create_triangle_constructions(new_model(), 42) end,
}) do
  local result = call()
  assert(result.created == false and result.status == "error")
  assert_contains(result.error, "options must be a table")
end
local malformed = api.create_triangle_centers(new_model(), {
  points = { true, { x = 4, y = 0 }, { x = 1, y = 3 } },
})
assert(malformed.created == false)
assert_contains(malformed.error, "points[1]")
local unknown = api.create_triangle_constructions(new_model(), {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  centers = "centroid", typo = true,
})
assert(unknown.created == false)
assert_contains(unknown.error, "unsupported field 'typo'")
local nested = api.create_triangle_constructions(new_model(), {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  centers = "centroid", center_features = { typo = true },
})
assert(nested.created == false)
assert_contains(nested.error, "center_features contains unsupported field 'typo'")
''')

    def test_selection_accepts_triangle_path_three_marks_and_three_sides(self) -> None:
        self.assert_lua_passes(r'''
local path_model = new_model({
  { object = triangle_path({ x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 }), selected = 1, layer = "beta" },
})
local path_result = api.create_triangle_centers(path_model, { center = "centroid" })
assert(path_result.created and path_result.result.source_kind == "path")
assert(path_result.result.output_layer == "alpha")

local mark_model = new_model({
  { object = mark(0, 0), selected = 1 },
  { object = mark(4, 0), selected = 2 },
  { object = mark(1, 3), selected = 2 },
})
local mark_result = api.create_triangle_derived(mark_model, { operation = "medial_triangle" })
assert(mark_result.created and mark_result.result.source_kind == "marks")

local side_model = new_model({
  { object = segment(0, 0, 4, 0), selected = 1, layer = "beta" },
  { object = segment(4, 0, 1, 3), selected = 2, layer = "beta" },
  { object = segment(1, 3, 0, 0), selected = 2, layer = "beta" },
})
local side_result = api.create_triangle_centers(side_model, {
  center = "incenter", output_layer = "source",
})
assert(side_result.created and side_result.result.source_kind == "sides")
assert(side_result.result.output_layer == "beta")
''')

    def test_selected_paths_use_stable_vertices_without_helper_marks(self) -> None:
        self.assert_lua_passes(r'''
local top, left, right = { x = 1, y = 4 }, { x = 0, y = 0 }, { x = 6, y = 0 }
local permutations = {
  { left, right, top },
  { right, left, top },
  { top, left, right },
}
local expected
for _, points in ipairs(permutations) do
  local model = new_model({
    { object = triangle_path(points[1], points[2], points[3]), selected = 1 },
  })
  local result = api.create_triangle_centers(model, {
    center = "excenter_a", marks = true, labels = false, group_output = false,
  })
  assert(result.created == true, result.error)
  assert(result.element_count == 1)
  assert(result.result.vertex_order == "upper_ccw")
  local position = model.entries[#model.entries].object:position()
  if expected then
    assert(approximate(position.x, expected.x, 1e-10))
    assert(approximate(position.y, expected.y, 1e-10))
  else
    expected = position
  end
end

local mark_model = new_model({
  { object = mark(0, 0), selected = 2 },
  { object = mark(6, 0), selected = 2 },
  { object = mark(1, 4), selected = 1 },
})
local marked = api.create_triangle_centers(mark_model, {
  center = "excenter_a", marks = true, labels = false, group_output = false,
})
assert(marked.created == true, marked.error)
assert(marked.element_count == 1)
assert(marked.result.vertex_order == "primary_a_ccw")
local marked_position = mark_model.entries[#mark_model.entries].object:position()
assert(approximate(marked_position.x, expected.x, 1e-10))
assert(approximate(marked_position.y, expected.y, 1e-10))
''')

    def test_selection_accepts_triangle_plus_mark_and_four_mark_contract(self) -> None:
        self.assert_lua_passes(r'''
local path_model = new_model({
  { object = triangle_path({ x = 0, y = 0 }, { x = 6, y = 0 }, { x = 1, y = 4 }), selected = 1 },
  { object = mark(2, 1), selected = 2 },
})
local pedal = api.create_triangle_derived(path_model, { operation = "pedal_triangle" })
assert(pedal.created == true, pedal.error)
assert(approximate(pedal.result.derived.pedal_triangle.reference_point.x, 2))

local marks_model = new_model({
  { object = mark(2, 1), selected = 1 },
  { object = mark(0, 0), selected = 2 },
  { object = mark(6, 0), selected = 2 },
  { object = mark(1, 4), selected = 2 },
})
local conjugate = api.create_triangle_derived(marks_model, { operation = "isogonal_conjugate" })
assert(conjugate.created == true, conjugate.error)
assert(approximate(conjugate.result.derived.isogonal_conjugate.reference_point.x, 2))

local extra = new_model({
  { object = triangle_path({ x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 }), selected = 1 },
  { object = ipe.Text({}, "extra", { x = 0, y = 0 }), selected = 2 },
})
local rejected = api.create_triangle_centers(extra, {})
assert(rejected.created == false)
assert_contains(rejected.error, "unsupported object")
''')

    def test_active_attributes_layers_grouping_and_selection_states(self) -> None:
        self.assert_lua_passes(r'''
local attributes = {
  stroke = "red", pen = "fat", dashstyle = "dotted", fill = "blue",
  farrow = "arrow/normal(spx)", decoration = "something",
  markshape = "mark/cross(sx)", symbolsize = "large", textsize = "large",
}
local grouped_model = new_model(nil, {
  attributes = attributes,
  invisible_layers = { alpha = true },
  locked_layers = { alpha = true },
})
local grouped = api.create_triangle_centers(grouped_model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  centers = { "centroid", "incenter" }, marks = true, auxiliaries = true,
})
assert(grouped.created and #grouped_model.entries == 1)
local group = grouped_model.entries[1].object
assert(group:type() == "group" and grouped_model.entries[1].selected == 1)
local children = group:elements()
assert(#children == grouped.element_count)
local saw_mark, saw_path = false, false
for _, child in ipairs(children) do
  if child:type() == "reference" then
    saw_mark = true
    assert(child.attributes.stroke == "red")
    assert(child.attributes.symbolsize == "large")
    assert(child:symbol() == "mark/cross(sx)")
  elseif child:type() == "path" then
    saw_path = true
    assert(child.attributes.stroke == "red" and child.attributes.pen == "fat")
    assert(child.attributes.fill == nil and child.attributes.farrow == nil)
  end
end
assert(saw_mark and saw_path)
assert(grouped_model.warnings[1].title == "Triangles output layer")
assert_contains(grouped_model.warnings[1].detail, "invisible")
assert_contains(grouped_model.warnings[1].detail, "locked")

local separate_model = new_model()
local separate = api.create_triangle_centers(separate_model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  centers = { "centroid", "incenter" }, group_output = false,
})
assert(separate.created and #separate_model.entries == 2)
assert(separate_model.entries[1].selected == 1)
assert(separate_model.entries[2].selected == 2)
''')

    def test_labels_are_independent_of_marks_and_semantic(self) -> None:
        self.assert_lua_passes(r'''
local center_model = new_model()
local center = api.create_triangle_centers(center_model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  center = "centroid", marks = false, labels = true,
})
assert(center.created and center.element_count == 1)
assert(center_model.entries[1].object:type() == "text")
assert(center_model.entries[1].object:text() == "$G$")

local derived_model = new_model()
local derived = api.create_triangle_derived(derived_model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  operation = "orthic_triangle", polygon = false, marks = false, labels = true,
  group_output = false,
})
assert(derived.created and derived.element_count == 3)
assert(derived_model.entries[1].object:text() == "$H_a$")
assert(derived_model.entries[2].object:text() == "$H_b$")
assert(derived_model.entries[3].object:text() == "$H_c$")
''')

    def test_labels_clear_existing_geometry_and_one_another(self) -> None:
        self.assert_lua_passes(r'''
local points = { { x = 0, y = 0 }, { x = 8, y = 0 }, { x = 1.5, y = 5 } }
local plan = api.build_construction_plan(new_model(), {
  points = points,
  centers = { "centroid", "incenter", "circumcenter", "orthocenter", "nine_point_center" },
  center_features = { mark = true, label = true, defining_lines = true },
})
local labels = {}
for _, specification in ipairs(plan.specifications) do
  if specification.type == "text" then labels[#labels + 1] = specification.point end
end
assert(#labels == 5)
local function segment_distance(point, first, second)
  local dx, dy = second.x - first.x, second.y - first.y
  local squared = dx * dx + dy * dy
  local t = ((point.x - first.x) * dx + (point.y - first.y) * dy) / squared
  t = math.max(0, math.min(1, t))
  local px, py = first.x + t * dx, first.y + t * dy
  return math.sqrt((point.x - px) ^ 2 + (point.y - py) ^ 2)
end
for index, point in ipairs(labels) do
  for side = 1, 3 do
    local next_side = side == 3 and 1 or side + 1
    assert(segment_distance(point, points[side], points[next_side]) > 3.0)
  end
  for other = index + 1, #labels do
    local dx, dy = point.x - labels[other].x, point.y - labels[other].y
    assert(math.sqrt(dx * dx + dy * dy) > 7.0)
  end
end

local created_model = new_model()
local created = api.create_triangle_centers(created_model, {
  points = points, center = "centroid", marks = false, labels = true,
})
assert(created.created == true, created.error)
local attributes = created_model.entries[1].object.attributes
assert(attributes.horizontalalignment == "hcenter")
assert(attributes.verticalalignment == "vcenter")

local function label_distance(textsize)
  local sized_model = new_model(nil, { attributes = { textsize = textsize } })
  local sized_plan = api.build_construction_plan(sized_model, {
    points = points, centers = { "centroid" },
    center_features = { mark = true, label = true },
  })
  local mark_point, label_point
  for _, specification in ipairs(sized_plan.specifications) do
    if specification.type == "mark" then mark_point = specification.point end
    if specification.type == "text" then label_point = specification.point end
  end
  local dx, dy = label_point.x - mark_point.x, label_point.y - mark_point.y
  return math.sqrt(dx * dx + dy * dy)
end
assert(label_distance("LARGE") > label_distance("normal") * 1.5)
''')

    def test_metadata_roles_fingerprints_and_inspection(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  center = "centroid", marks = true, labels = false, group_output = false,
})
assert(result.created and #model.entries == 1)
local object = model.entries[1].object
local current = api.parse_metadata(object)
assert(current.status == "current")
assert(current.fields.role == "center")
assert(current.fields.kind == "centroid")
assert(current.fields.source:find("|", 1, true))
assert(current.fields.source_fingerprint:match("^[0-9a-f]+$"))

object.position_value = {
  x = tonumber(string.format("%.6g", object.position_value.x)),
  y = tonumber(string.format("%.6g", object.position_value.y)),
}
assert(api.parse_metadata(object).status == "current")

object.position_value = { x = object.position_value.x + 1, y = object.position_value.y }
local stale = api.parse_metadata(object)
assert(stale.status == "stale")
local inspected = api.inspect_selected_construction(model, {})
assert(inspected.status == "inspected")
assert(inspected.result.stale == 1)
''')

    def test_preview_and_final_creation_share_the_same_plan(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local options = {
  points = { { x = 0, y = 0 }, { x = 6, y = 0 }, { x = 1, y = 4 } },
  centers = { "centroid", "incenter", "circumcenter" },
  center_features = { mark = true, label = true, auxiliaries = true, circle = true },
  derived = { "orthic_triangle", "nine_point_points" },
  derived_polygon = true, derived_marks = true, derived_labels = true,
  derived_circle = true,
}
local preview = api.preview_shape_data(model, options)
assert(#model.entries == 0)
assert(preview.element_count > 0 and preview.shape_count >= preview.element_count)
local signature_a = api.preview_signature(model, options)
options.points[1].x = 1e-12
local signature_b = api.preview_signature(model, options)
assert(signature_a ~= signature_b)
options.points[1].x = 0
local created = api.create_triangle_constructions(model, options)
assert(created.created == true, created.error)
assert(created.element_count == preview.element_count)
''')

    def test_metadata_survives_ipe_text_and_coordinate_normalization(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  center = "centroid", marks = false, labels = true, group_output = false,
})
assert(result.created and #model.entries == 1)
local object = model.entries[1].object
assert(object:text() == "$G$")
assert(api.parse_metadata(object).status == "current")

object.text_value = "G"
object.position_value = {
  x = tonumber(string.format("%.6g", object.position_value.x)),
  y = tonumber(string.format("%.6g", object.position_value.y)),
}
assert(api.parse_metadata(object).status == "current")

object.position_value.x = object.position_value.x + 0.01
assert(api.parse_metadata(object).status == "stale")
''')

    def test_defining_perpendicular_bisectors_reach_the_circumcenter(self) -> None:
        self.assert_lua_passes(r'''
local points = { { x = 0, y = 0 }, { x = 8, y = 0 }, { x = 1, y = 0.3 } }
local center = api.triangle_center(points[1], points[2], points[3], "circumcenter").point
local model = new_model()
local result = api.create_triangle_centers(model, {
  points = points, center = "circumcenter", marks = false,
  auxiliaries = true, group_output = false,
})
assert(result.created and result.element_count == 3)
for _, entry in ipairs(model.entries) do
  local segment_value = entry.object:shape()[1][1]
  local first, second = segment_value[1], segment_value[2]
  local cross_value = (second.x - first.x) * (center.y - first.y)
    - (second.y - first.y) * (center.x - first.x)
  assert(math.abs(cross_value) < 1e-7 * math.max(1,
    math.abs(second.x - first.x), math.abs(second.y - first.y)))
  local between = (center.x - first.x) * (center.x - second.x)
    + (center.y - first.y) * (center.y - second.y)
  assert(between <= 1e-7)
end
''')

    def test_right_triangle_perpendicular_bisectors_are_not_degenerate(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 6, y = 0 }, { x = 0, y = 8 } },
  center = "circumcenter", marks = false,
  defining_lines = true, group_output = false,
})
assert(result.created and result.element_count == 3)
for _, entry in ipairs(model.entries) do
  local segment_value = entry.object:shape()[1][1]
  local first, second = segment_value[1], segment_value[2]
  assert((second.x - first.x)^2 + (second.y - first.y)^2 > 1e-12)
end
''')

    def test_transaction_undo_and_redo_preserve_one_primary_selection(self) -> None:
        self.assert_lua_passes(r'''
local model, _, document = new_model()
local result = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  centers = { "centroid", "incenter" }, group_output = false,
})
assert(result.created and #model.entries == 2)
model.registration:undo(document)
assert(#model.entries == 0)
model.registration:redo(document)
assert(#model.entries == 2)
assert(model.entries[1].selected == 1 and model.entries[2].selected == 2)
''')

    def test_dialogs_have_valid_controls_cleanup_preview_and_create_defaults(self) -> None:
        self.assert_lua_passes(r'''
local accept_dialog = false
ipeui.Dialog = function(_, title)
  local dialog = { title = title, values = {}, enabled = {}, buttons = {} }
  function dialog:add(name, kind, data)
    self.values[name] = self.values[name]
    self.enabled[name] = true
    if kind == "combo" and self.values[name] == nil then self.values[name] = 1 end
    if kind == "checkbox" and self.values[name] == nil then self.values[name] = false end
    if kind == "input" and self.values[name] == nil then self.values[name] = "" end
    assert(data ~= nil)
  end
  function dialog:set(name, value) assert(self.enabled[name] ~= nil, name); self.values[name] = value end
  function dialog:get(name) assert(self.enabled[name] ~= nil, name); return self.values[name] end
  function dialog:setEnabled(name, value) assert(self.enabled[name] ~= nil, name); self.enabled[name] = value end
  function dialog:addButton(name, _, action) self.buttons[name] = action end
  function dialog:execute() return accept_dialog end
  return dialog
end

local function selected_triangle_model()
  return new_model({
    { object = triangle_path(
      { x = 0, y = 0 }, { x = 5, y = 0 }, { x = 1, y = 4 }
    ), selected = 1, layer = "alpha" },
  })
end

local cancelled = selected_triangle_model()
assert(_G.TRIANGLES_DIALOGS.centers(cancelled) == false)
assert(cancelled.ui.finished_tools == 1)
assert(cancelled.ui.current_tool == nil)

accept_dialog = true
local centers = selected_triangle_model()
local center_result = _G.TRIANGLES_DIALOGS.centers(centers)
assert(center_result.created == true, center_result.error)
assert(center_result.center_count == 1)
assert(centers.ui.finished_tools == 1 and centers.ui.current_tool == nil)

local derived = selected_triangle_model()
local derived_result = _G.TRIANGLES_DIALOGS.derived(derived)
assert(derived_result.created == true, derived_result.error)
assert(derived_result.derived_count == 1)
assert(derived.ui.finished_tools == 1 and derived.ui.current_tool == nil)
''')

    def test_dialog_state_survives_runtime_reload(self) -> None:
        self.assert_lua_passes(r'''
local original = api.dialog_state
original.centers.preset = 4
original.derived.operation = 7
dofile(TRIANGLES_PATH)
local reloaded = assert(_G.TRIANGLES)
assert(reloaded.dialog_state == original)
assert(reloaded.dialog_state.centers.preset == 4)
assert(reloaded.dialog_state.derived.operation == 7)
assert(reloaded.is_compatible(1))
''')


if __name__ == "__main__":
    unittest.main()
