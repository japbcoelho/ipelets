import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRIANGLES = ROOT / "triangles.lua"
RUNTIME = ROOT / "tests/triangles_runtime.lua"


class TrianglesRegressionTest(unittest.TestCase):
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

    def test_named_presets_are_mathematically_grouped_and_legacy_aliases_remain(self) -> None:
        self.assert_lua_passes(r'''
local fundamental = api.center_name_list("fundamental")
local contact = api.center_name_list("contact_cevian")
local euler = api.center_name_list("euler_line_centers")
local isogonal = api.center_name_list("isogonal_napoleon")
assert(#fundamental == 5)
assert(fundamental[1] == "centroid" and fundamental[5] == "nine_point_center")
assert(#contact == 9 and contact[1] == "incenter" and contact[9] == "nagel_point")
assert(#euler == 6 and euler[1] == "centroid" and euler[6] == "exeter_point")
assert(#isogonal == 9 and isogonal[1] == "symmedian_point")
assert(isogonal[4] == "first_fermat" and isogonal[5] == "second_fermat")
assert(api.center_name_list("first_isogonic")[1] == "first_fermat")
assert(api.center_name_list("second_isogonic")[1] == "second_fermat")
assert(#api.center_name_list("all_classic") == 5)
assert(#api.center_name_list("all_advanced") == 19)
assert(#api.center_name_list("all_centers") == 24)
''')

    def test_defining_lines_are_center_specific_and_center_circles_are_not_duplicated(self) -> None:
        self.assert_lua_passes(r'''
local points = { { x = 0, y = 0 }, { x = 7, y = 0 }, { x = 2, y = 5 } }

local function roles_for(center)
  local plan = api.build_construction_plan(new_model(), {
    points = points, centers = { center },
    center_features = { mark = true, defining_lines = true },
    group_output = false,
  })
  local roles = {}
  for _, specification in ipairs(plan.specifications) do
    roles[specification.role] = (roles[specification.role] or 0) + 1
  end
  return plan, roles
end

local _, centroid_roles = roles_for("centroid")
assert(centroid_roles.median == 3)
local _, incenter_roles = roles_for("incenter")
assert(incenter_roles.angle_bisector == 3)
local _, circumcenter_roles = roles_for("circumcenter")
assert(circumcenter_roles.perpendicular_bisector == 3)
local _, symmedian_roles = roles_for("symmedian_point")
assert(symmedian_roles.symmedian == 3)
local feuerbach_plan, feuerbach_roles = roles_for("feuerbach_point")
assert(#feuerbach_plan.specifications == 1)
assert(feuerbach_roles.center == 1)

local incenter_plan = api.build_construction_plan(new_model(), {
  points = points, centers = { "incenter" },
  center_features = { mark = true, circle = true },
})
assert(#incenter_plan.specifications == 1)
assert(#incenter_plan.issues == 1)
assert(incenter_plan.issues[1].name == "nine_point_circle")

local nine_point_plan = api.build_construction_plan(new_model(), {
  points = points, centers = { "nine_point_center" },
  center_features = { mark = false, circle = true },
})
assert(#nine_point_plan.specifications == 1)
assert(nine_point_plan.specifications[1].type == "circle")
assert(nine_point_plan.specifications[1].kind == "nine_point_circle")

local contact_plan = api.build_construction_plan(new_model(), {
  points = points, derived = { "contact_triangle" },
  center_features = { mark = false, contact_marks = true },
  derived_polygon = true, derived_marks = true, derived_circle = true,
  contact_circle = "excircle_b",
})
local saw_excircle = false
for _, specification in ipairs(contact_plan.specifications) do
  if specification.type == "circle" and specification.kind == "excircle_b" then
    saw_excircle = true
  end
end
assert(saw_excircle)
''')

    def test_every_derived_construction_returns_finite_expected_cardinality(self) -> None:
        self.assert_lua_passes(r'''
local a, b, c = { x = 0, y = 0 }, { x = 7, y = 0 }, { x = 2, y = 5 }
local point = { x = 2.5, y = 1.4 }
local expected = {
  medial_triangle = 3, orthic_triangle = 3, contact_triangle = 3,
  excentral_triangle = 3, pedal_triangle = 3, nine_point_points = 9,
  cevian_endpoints = 3, isogonal_conjugate = 1, isotomic_conjugate = 1,
}
for operation, count in pairs(expected) do
  local options = { operation = operation, contact_circle = "excircle_b" }
  if operation == "pedal_triangle" or operation == "cevian_endpoints"
      or operation == "isogonal_conjugate" or operation == "isotomic_conjugate" then
    options.point = point
  end
  local result = api.triangle_derived_points(a, b, c, options)
  assert(result.status == "finite", operation .. ": " .. tostring(result.reason))
  assert(#result.points == count, operation)
  assert(#result.labels == count, operation .. " labels")
  for _, value in ipairs(result.points) do
    assert(api.finite_number(value.x) and api.finite_number(value.y), operation)
  end
end
''')

    def test_contact_points_lie_on_each_sideline_for_all_four_circles(self) -> None:
        self.assert_lua_passes(r'''
local a, b, c = { x = -1, y = 1 }, { x = 6, y = 0 }, { x = 2, y = 5 }
local sides = { { a, b }, { b, c }, { c, a } }
for _, kind in ipairs({ "incircle", "excircle_a", "excircle_b", "excircle_c" }) do
  local result = api.triangle_contact_points(a, b, c, kind)
  assert(#result.points == 3 and result.circle.radius > 0)
  for index, point in ipairs(result.points) do
    local first, second = sides[index][1], sides[index][2]
    local side_x, side_y = second.x - first.x, second.y - first.y
    local cross_value = side_x * (point.y - first.y) - side_y * (point.x - first.x)
    assert(math.abs(cross_value) < 1e-8, kind .. " contact " .. tostring(index))
    local radius_x = point.x - result.circle.center.x
    local radius_y = point.y - result.circle.center.y
    assert(math.abs(side_x * radius_x + side_y * radius_y) < 1e-8,
      kind .. " perpendicular " .. tostring(index))
  end
end
''')

    def test_path_parser_rejects_disconnected_or_curved_closed_paths(self) -> None:
        self.assert_lua_passes(r'''
local disconnected = ipe.Path({}, {
  { type = "curve", closed = true;
    { type = "segment"; { x = 0, y = 0 }, { x = 4, y = 0 } },
    { type = "segment"; { x = 5, y = 0 }, { x = 1, y = 3 } } },
})
assert(api.triangle_path_vertices(disconnected) == nil)
local curved = ipe.Path({}, {
  { type = "curve", closed = true;
    { type = "spline"; { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
    { type = "segment"; { x = 1, y = 3 }, { x = 0, y = 0 } } },
})
assert(api.triangle_path_vertices(curved) == nil)
local model = new_model({ { object = disconnected, selected = 1 } })
local result = api.create_triangle_centers(model, {})
assert(result.created == false)
assert_contains(result.error, "unsupported object")
''')

    def test_three_side_selection_rejects_gaps_duplicates_and_extra_objects(self) -> None:
        self.assert_lua_passes(r'''
for _, entries in ipairs({
  {
    { object = segment(0, 0, 4, 0), selected = 1 },
    { object = segment(4, 0, 1, 3), selected = 2 },
    { object = segment(1.1, 3, 0, 0), selected = 2 },
  },
  {
    { object = segment(0, 0, 4, 0), selected = 1 },
    { object = segment(4, 0, 0, 0), selected = 2 },
    { object = segment(1, 3, 0, 0), selected = 2 },
  },
  {
    { object = segment(0, 0, 4, 0), selected = 1 },
    { object = segment(4, 0, 1, 3), selected = 2 },
    { object = segment(1, 3, 0, 0), selected = 2 },
    { object = mark(2, 1), selected = 2 },
  },
}) do
  local model = new_model(entries)
  local result = api.create_triangle_centers(model, {})
  assert(result.created == false)
end
''')

    def test_circle_contact_and_polygon_roles_are_versioned_per_object(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_triangle_constructions(model, {
  points = { { x = 0, y = 0 }, { x = 7, y = 0 }, { x = 2, y = 5 } },
  centers = { "incenter", "circumcenter", "nine_point_center" },
  center_features = { mark = true, circle = true, contact_marks = true },
  derived = { "contact_triangle", "nine_point_points" },
  derived_polygon = true, derived_marks = true, derived_circle = true,
  contact_circle = "incircle", group_output = true,
})
assert(result.created == true, result.error)
local group = model.entries[1].object
local group_metadata = api.parse_metadata(group)
assert(group_metadata.status == "current")
assert(group_metadata.fields.role == "group")
assert(tonumber(group_metadata.fields.count) == result.element_count)
local roles = {}
for _, child in ipairs(group:elements()) do
  local metadata = api.parse_metadata(child)
  assert(metadata.status == "current")
  roles[metadata.fields.role] = true
  assert(metadata.fields.id == group_metadata.fields.id)
  assert(metadata.fields.source == group_metadata.fields.source)
end
assert(roles.center and roles.circle and roles.combined and roles.polygon and roles.derived_point)
''')

    def test_full_precision_source_metadata_distinguishes_small_coordinate_changes(self) -> None:
        self.assert_lua_passes(r'''
local function source_for(delta)
  local model = new_model()
  local result = api.create_triangle_centers(model, {
    points = { { x = delta, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
    center = "centroid", group_output = false,
  })
  assert(result.created)
  return api.parse_metadata(model.entries[1].object).fields
end
local first = source_for(0)
local second = source_for(1e-12)
assert(first.source ~= second.source)
assert(first.source_fingerprint ~= second.source_fingerprint)
''')

    def test_explicit_geometry_has_precedence_over_unrelated_selection(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model({
  { object = ipe.Text({}, "unrelated", { x = 99, y = 99 }), selected = 1 },
})
local result = api.create_triangle_centers(model, {
  points = { { x = 0, y = 0 }, { x = 4, y = 0 }, { x = 1, y = 3 } },
  center = "centroid", group_output = false,
})
assert(result.created == true, result.error)
assert(result.result.source_kind == "explicit")
local point = model.entries[#model.entries].object:position()
assert(approximate(point.x, 5 / 3) and approximate(point.y, 1))
''')

    def test_no_created_geometry_contains_nan_or_infinity(self) -> None:
        self.assert_lua_passes(r'''
local function inspect_value(value, seen)
  local value_type = type(value)
  if value_type == "number" then
    assert(api.finite_number(value))
  elseif value_type == "table" then
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true
    for key, item in pairs(value) do
      inspect_value(key, seen)
      inspect_value(item, seen)
    end
  end
end
for _, factor in ipairs({ 1e-200, 1e-50, 1, 1e50, 1e200 }) do
  local model = new_model()
  local result = api.create_triangle_constructions(model, {
    points = {
      { x = 0, y = 0 }, { x = 4 * factor, y = 0 },
      { x = factor, y = 3 * factor },
    },
    centers = "all_centers",
    center_features = { mark = true, circle = true, auxiliaries = true },
    derived = { "orthic_triangle", "nine_point_points" },
    derived_polygon = true, derived_marks = true, derived_circle = true,
  })
  assert(result.created == true, result.error)
  inspect_value(model.entries)
end
''')


if __name__ == "__main__":
    unittest.main()
