import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONICS = ROOT / "conics.lua"
RUNTIME = ROOT / "tests/conics_runtime.lua"


class ConicsContractTest(unittest.TestCase):
    maxDiff = None

    def run_lua(self, body: str) -> subprocess.CompletedProcess[str]:
        script = (
            f"CONICS_PATH={json.dumps(str(CONICS))}\n"
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

    def test_standalone_api_surface_and_product_isolation(self):
        self.assert_lua_passes(r'''
assert(_G.GEOMETRY == nil)
assert(_G.GEOMETRY_DIALOGS == nil)
assert(_G.IPE_MCP_BRIDGE_STATE == nil)
assert(api.api_version == 1)
assert(api.version == "1.1.0")
assert(api.is_compatible(1) == true)
assert(api.is_compatible(2) == false)
for _, name in ipairs(api.required_functions) do
  assert(type(api[name]) == "function", name)
end
assert(type(_G.CONICS_DIALOGS) == "table")
assert(#methods == 7)
assert(methods[1].label == "Construct: conic")
assert(methods[2].label == "Construct: ellipse")
assert(methods[3].label == "Construct: hyperbola")
assert(methods[4].label == "Construct: parabola")
assert(methods[5].label == "Features: conic")
assert(methods[6].label == "Inspect: conic")
assert(methods[7].label == "Metadata: revalidate selected conic")
''')
        source = CONICS.read_text(encoding="utf-8")
        for forbidden in (
            "IPE_MCP_BRIDGE_STATE",
            "IPE_GEOMETRY_API",
            "IPE_GEOMETRY_DIALOGS",
            "_G.GEOMETRY",
            "/home/",
            ".codex",
            "mailbox",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", source)
        self.assertIn("Standalone construction", source)

    def test_public_creators_validate_option_types_and_nested_schemas(self):
        self.assert_lua_passes(r'''
local calls = {
  function() return api.create_conic(new_model(), true) end,
  function() return api.create_ellipse_from_foci(new_model(), "bad") end,
  function() return api.create_hyperbola(new_model(), 42) end,
  function() return api.create_parabolas(new_model(), false) end,
  function() return api.create_conic_features(new_model(), "bad") end,
  function() return api.inspect_conic(new_model(), 42) end,
}
for _, callback in ipairs(calls) do
  local result = callback()
  assert(result.created == false and result.status == "error")
  assert_contains(result.error, "options must be a table")
end

local unknown_top = api.create_hyperbola(new_model(), {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  unrelated = true,
})
assert(unknown_top.created == false)
assert_contains(unknown_top.error, "unsupported field")

local unknown_nested = api.create_conic(new_model(), {
  operation = "five_points",
  definition = {
    points = {
      { x = 5, y = 0 }, { x = 0, y = 5 }, { x = -5, y = 0 },
      { x = 0, y = -5 }, { x = 3, y = 4 },
    },
    typo = true,
  },
})
assert(unknown_nested.created == false)
assert_contains(unknown_nested.error, "conic definition contains unsupported field 'typo'")

local unknown_input = api.create_conic_features(new_model(), {
  operation = "tangent",
  definition = { coefficients = { 1, 0, 1, 0, 0, -25 } },
  feature_input = { point = { x = 5, y = 0 }, typo = true },
})
assert(unknown_input.created == false)
assert_contains(unknown_input.error, "feature input contains unsupported field 'typo'")
''')

    def test_operation_specific_parsing_and_explicit_precedence(self):
        self.assert_lua_passes(r'''
local selected_ellipse = ipe.Path({}, {
  { type = "ellipse"; ipe.Matrix(2, 0, 0, 1, 0, 0) },
})
local stale_mark = mark(2, 0)
local model = new_model({
  { object = selected_ellipse, selected = 1, layer = "alpha" },
  { object = stale_mark, selected = 2, layer = "alpha" },
})
local explicit_circle_points = {
  { x = 110, y = 0 }, { x = 100, y = 10 }, { x = 90, y = 0 },
  { x = 100, y = -10 }, { x = 106, y = 8 },
}
local result = api.create_conic_features(model, {
  operation = "tangent",
  definition = { points = explicit_circle_points },
  feature_input = { point = { x = 110, y = 0 } },
  marks = false,
})
assert(result.created == true, result.error)
assert(approximate(result.result.point.x, 110))

local valid_with_irrelevant_legacy_budget = api.create_conic(new_model(), {
  operation = "five_points",
  points = {
    { x = 5, y = 0 }, { x = 0, y = 5 }, { x = -5, y = 0 },
    { x = 0, y = -5 }, { x = 3, y = 4 },
  },
  samples = "ignored-for-an-exact-ellipse",
})
assert(valid_with_irrelevant_legacy_budget.created == true, valid_with_irrelevant_legacy_budget.error)

local rejected_irrelevant_unknown = api.create_hyperbola(new_model(), {
  operation = "foci_point",
  focus_a = { x = -20, y = 0 }, focus_b = { x = 20, y = 0 },
  point = { x = 30, y = 10 }, points = { { x = "bad", y = 0 } },
})
assert(rejected_irrelevant_unknown.created == false)
assert_contains(rejected_irrelevant_unknown.error, "unsupported field 'points'")
''')

    def test_line_alias_and_strict_selection_contracts(self):
        self.assert_lua_passes(r'''
local vertical = { p1 = { x = 0, y = -10 }, p2 = { x = 0, y = 10 } }
local by_line = api.create_hyperbola(new_model(), {
  operation = "parameters", center = { x = 0, y = 0 }, line = vertical,
  a = 20, b = 10, branch = "right", asymptotes = false,
})
local by_axis = api.create_hyperbola(new_model(), {
  operation = "parameters", center = { x = 0, y = 0 }, axis = vertical,
  a = 20, b = 10, branch = "right", asymptotes = false,
})
assert(by_line.created and by_axis.created)
for index = 1, 6 do
  assert(approximate(by_line.result.coefficients[index], by_axis.result.coefficients[index]))
end

local fake_model = new_model({
  { object = mark(0, 0, "symbol/not-a-mark"), selected = 1 },
  { object = mark(10, 0, "symbol/not-a-mark"), selected = 2 },
  { object = mark(0, 10, "symbol/not-a-mark"), selected = 2 },
})
local fake_result = api.create_conic(fake_model, { operation = "steiner" })
assert(fake_result.created == false)
assert_contains(fake_result.error, "Select exactly three marks")

local extra_model = new_model({
  { object = mark(0, 0), selected = 1 },
  { object = mark(10, 0), selected = 2 },
  { object = mark(0, 10), selected = 2 },
  { object = ipe.Text({}, "extra", { x = 5, y = 5 }), selected = 2 },
})
local extra_result = api.create_conic(extra_model, { operation = "steiner" })
assert(extra_result.created == false)
assert_contains(extra_result.error, "Select exactly three marks")

local directrix = segment(-20, -10, 20, -10)
local focus = mark(0, 10)
local point = mark(0, 0)
local correct = new_model({
  { object = focus, selected = 2 },
  { object = directrix, selected = 2 },
  { object = point, selected = 1 },
})
assert(api.create_conic(correct, { operation = "focus_directrix_point" }).created)
local wrong = new_model({
  { object = focus, selected = 1 },
  { object = directrix, selected = 2 },
  { object = point, selected = 2 },
})
local wrong_result = api.create_conic(wrong, { operation = "focus_directrix_point" })
assert(wrong_result.created == true)
assert(math.abs(api.evaluate_conic(wrong_result.result.coefficients, { x = 0, y = 10 })) < 1e-8)
assert(math.abs(api.evaluate_conic(wrong_result.result.coefficients, { x = 0, y = 0 })) > 1e-3)
''')

    def test_active_layer_attributes_and_multi_output_selection_states(self):
        self.assert_lua_passes(r'''
local attributes = {
  stroke = "red", pen = "fat", dashstyle = "dotted", fill = "blue",
  farrow = "arrow/normal(spx)", decoration = "something",
  markshape = "mark/cross(sx)", symbolsize = "large",
}
local model = new_model(nil, {
  attributes = attributes,
  invisible_layers = { alpha = true },
})
local result = api.create_conic(model, {
  operation = "steiner", group_output = false,
  points = { { x = 0, y = 0 }, { x = 60, y = 0 }, { x = 0, y = 40 } },
})
assert(result.created == true)
assert(#model.entries == 2)
assert(model.entries[1].selected == 1)
assert(model.entries[2].selected == 2)
assert(model.entries[1].layer == "alpha" and model.entries[2].layer == "alpha")
local style = model.entries[1].object.attributes
assert(style.stroke == "red" and style.pen == "fat" and style.dashstyle == "dotted")
assert(style.fill == nil and style.farrow == nil and style.decoration == nil)
assert(model.last_warning and model.last_warning.title == "Active layer is invisible")

local hyperbola_model = new_model()
local hyperbola = api.create_hyperbola(hyperbola_model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  branch = "both", asymptotes = true, group_output = false,
})
assert(hyperbola.created and #hyperbola_model.entries == 4)
assert(hyperbola_model.entries[1].selected == 1)
for index = 2, 4 do assert(hyperbola_model.entries[index].selected == 2) end

local grouped_model = new_model()
local grouped = api.create_hyperbola(grouped_model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  branch = "both", asymptotes = true,
})
assert(grouped.created and #grouped_model.entries == 1)
assert(grouped_model.entries[1].object:type() == "group")
assert(grouped_model.entries[1].selected == 1)
''')

    def test_metadata_namespace_roles_corruption_and_legacy_compatibility(self):
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_hyperbola(model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  branch = "both", asymptotes = true, group_output = false,
})
assert(result.created and #model.entries == 4)
for index = 1, 2 do
  local custom = model.entries[index].object.custom
  assert(custom:find("conics:v1", 1, true))
  assert(custom:find("role=branch", 1, true))
  assert(custom:find("coefficients=", 1, true))
end
for index = 3, 4 do
  local custom = model.entries[index].object.custom
  assert(custom:find("role=asymptote", 1, true))
  assert(not custom:find("coefficients=", 1, true))
  local coefficients, information = api.parse_conic_metadata(model.entries[index].object)
  assert(coefficients == nil and information.status == "auxiliary")
end

local foreign = segment(-10, 0, 10, 0)
foreign.custom = "other-plugin:data;coefficients=1,0,1,0,0,-25"
local foreign_model = new_model({ { object = foreign, selected = 1 } })
local foreign_result = api.inspect_conic(foreign_model, {})
assert(foreign_result.created == false and foreign_result.status == "error")
assert_contains(foreign_result.error, "not a conic curve")

local corrupt = model.entries[1].object
corrupt.custom = corrupt.custom:gsub("coefficients=[^;]+", "coefficients=1,2")
model.entries[1].selected = 1
for index = 2, #model.entries do model.entries[index].selected = nil end
local corrupt_result = api.inspect_conic(model, {})
assert(corrupt_result.status == "error")
assert_contains(corrupt_result.error, "exactly six coefficients")

local legacy = ipe.Path({}, { { type = "ellipse"; ipe.Matrix(5, 0, 0, 5, 0, 0) } })
legacy.custom = "geometry:conic;coefficients=1,0,1,0,0,-25"
local coefficients, information = api.parse_conic_metadata(legacy)
assert(#coefficients == 6 and information.status == "legacy")
''')

    def test_stale_metadata_detection_group_support_and_revalidation(self):
        self.assert_lua_passes(r'''
local model = new_model()
local created = api.create_ellipse_from_foci(model, {
  focus_a = { x = -10, y = 0 }, focus_b = { x = 10, y = 0 },
  point = { x = 0, y = 15 },
})
assert(created.created)
local ellipse = model.entries[1].object
ellipse.data[1][1] = ipe.Matrix(18, 0, 0, 9, 0, 0)
model.entries[1].selected = 1
local stale = api.inspect_conic(model, {})
assert(stale.status == "error")
assert_contains(stale.error, "stale")
local repaired = api.revalidate_metadata(model, {})
assert(repaired.status == "updated")
assert(repaired.result.updated_object_count == 1)
local inspected = api.inspect_conic(model, {})
assert(inspected.status == "inspected")
assert(inspected.result.properties.kind == "ellipse")

local point = mark(18, 0)
local group = ipe.Group({ ellipse })
local group_model = new_model({
  { object = group, selected = 1 },
  { object = point, selected = 2 },
})
local feature = api.create_conic_features(group_model, {
  operation = "tangent", line_length = 40, marks = false,
})
assert(feature.created == true, feature.error)
''')

    def test_feature_results_cover_created_computed_empty_and_infinite_states(self):
        self.assert_lua_passes(r'''
local circle = { 1, 0, 1, 0, 0, -25 }
local tangent = api.create_conic_features(new_model(), {
  operation = "tangent",
  definition = { coefficients = circle },
  feature_input = { point = { x = 5, y = 0 } },
  tangent = false,
})
assert(tangent.status == "error")
assert_contains(tangent.error, "cannot disable its tangent")

local neither = api.create_conic_features(new_model(), {
  operation = "tangent_normal",
  definition = { coefficients = circle },
  feature_input = { point = { x = 5, y = 0 } },
  tangent = false, normal = false,
})
assert(neither.status == "error")
assert_contains(neither.error, "at least the tangent or the normal")

local computed = api.create_conic_features(new_model(), {
  operation = "line_intersections",
  definition = { coefficients = circle },
  feature_input = { line = { p1 = { x = -10, y = 0 }, p2 = { x = 10, y = 0 } } },
  marks = false,
})
assert(computed.created == false and computed.status == "computed")
assert(computed.result.intersection_count == 2)

local empty = api.create_conic_features(new_model(), {
  operation = "line_intersections",
  definition = { coefficients = circle },
  feature_input = { line = { p1 = { x = -10, y = 10 }, p2 = { x = 10, y = 10 } } },
})
assert(empty.created == false and empty.status == "empty")
assert(empty.result.intersection_count == 0)

local infinite = api.create_conic_features(new_model(), {
  operation = "line_intersections",
  definition = { coefficients = { 0, 0, 0, 0, 1, 0 } },
  feature_input = { line = { p1 = { x = -10, y = 0 }, p2 = { x = 10, y = 0 } } },
})
assert(infinite.created == false and infinite.status == "infinite")
assert(infinite.result.infinite == true)

local partial = api.create_parabolas(new_model(), { focus = { x = 0, y = 10 } })
assert(partial.status == "error")
assert_contains(partial.error, "directrix and at least one focus are required")

local focus_on_directrix = api.create_parabolas(new_model(), {
  directrix = { p1 = { x = -20, y = 0 }, p2 = { x = 20, y = 0 } },
  foci = { { x = 0, y = 0 } },
})
assert(focus_on_directrix.status == "error")
assert_contains(focus_on_directrix.error, "focus must not lie on the directrix")
''')

    def test_numerical_stability_across_extreme_scales(self):
        self.assert_lua_passes(r'''
local roots = api.conic_line_intersections(
  { 1, 0, 0, -1e16, 0, 1 },
  { p1 = { x = 0, y = 0 }, p2 = { x = 1, y = 0 } }
)
assert(#roots == 2)
assert(roots[1].x > 0 and approximate(roots[1].x, 1e-16, 1e-6))
assert(approximate(roots[2].x, 1e16, 1e-12))

local distant_line = api.line_from_equation(1, 0, 1e300)
assert(distant_line.point.x == -1e300)
assert(distant_line.direction.y ~= 0)

local tiny = api.ellipse_from_foci_point(
  { x = -1e-10, y = 0 }, { x = 1e-10, y = 0 }, { x = 0, y = 2e-10 }
)
assert(tiny.major_radius > tiny.minor_radius and tiny.minor_radius > 0)

local huge_model = new_model()
local huge = api.create_ellipse_from_foci(huge_model, {
  focus_a = { x = -1e200, y = 0 }, focus_b = { x = 1e200, y = 0 },
  point = { x = 0, y = 2e200 },
})
assert(huge.created == true, huge.error)
assert(huge.result.coefficients_available == false)
assert_contains(huge_model.entries[1].object.custom, "coordinate_space=ellipse_shape")

local near_directrix_ok, near_directrix_error = pcall(
  api.focus_directrix_conic_coefficients,
  { x = 0, y = 1 },
  { p1 = { x = -1, y = 0 }, p2 = { x = 1, y = 0 } },
  { x = 0, y = 1e-15 }
)
assert(near_directrix_ok == false)
assert_contains(tostring(near_directrix_error), "too close to the directrix")

local distant = api.hyperbola_from_foci_point(
  { x = -100, y = 0 }, { x = 100, y = 0 }, { x = 1e6, y = 2000 }
)
assert(distant.point_parameter > 9)
local cubics, t_max = api.adaptive_hyperbola_cubics(distant, 1, nil, 0.25, 512)
assert(#cubics > 0 and t_max >= distant.point_parameter)
local endpoint = cubics[#cubics][4]
assert(approximate(endpoint.x, 1e6, 1e-10))
assert(approximate(endpoint.y, 2000, 1e-10))
''')

    def test_five_point_solver_preserves_input_and_rejects_degenerate_data(self):
        self.assert_lua_passes(r'''
local points = {
  { x = 5, y = 0 }, { x = 0, y = 5 }, { x = -5, y = 0 },
  { x = 0, y = -5 }, { x = 3, y = 4 },
}
local originals = { points[1], points[2], points[3], points[4], points[5] }
local coefficients = api.conic_coefficients_from_five_points(points)
assert(#coefficients == 6)
for index = 1, 5 do assert(points[index] == originals[index]) end

local duplicate_ok, duplicate_error = pcall(api.conic_coefficients_from_five_points, {
  { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 1, y = 0 },
  { x = 0, y = 1 }, { x = 1, y = 1 },
})
assert(duplicate_ok == false)
assert_contains(tostring(duplicate_error), "distinct points")

local degenerate_ok, degenerate_error = pcall(api.conic_coefficients_from_five_points, {
  { x = -2, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 0 },
  { x = 0, y = 1 }, { x = 0, y = 2 },
})
assert(degenerate_ok == false)
assert(tostring(degenerate_error):find("degenerate", 1, true)
  or tostring(degenerate_error):find("stable", 1, true))
''')

    def test_exact_and_adaptive_paths_are_compact_and_continuous(self):
        self.assert_lua_passes(r'''
local ellipse_model = new_model()
local ellipse = api.create_conic(ellipse_model, {
  operation = "five_points",
  points = {
    { x = 5, y = 0 }, { x = 0, y = 5 }, { x = -5, y = 0 },
    { x = 0, y = -5 }, { x = 3, y = 4 },
  },
})
assert(ellipse.created)
local ellipse_shape = ellipse_model.entries[1].object:shape()
assert(#ellipse_shape == 1 and ellipse_shape[1].type == "ellipse")

local parabola_model = new_model()
local parabola = api.create_parabolas(parabola_model, {
  directrix = { p1 = { x = -40, y = 0 }, p2 = { x = 40, y = 0 } },
  foci = { { x = 0, y = 20 } },
})
assert(parabola.created)
local parabola_curve = parabola_model.entries[1].object:shape()[1]
assert(#parabola_curve == 1)
assert(parabola_curve[1].type == "spline" and #parabola_curve[1] == 3)

local hyperbola_model = new_model()
local hyperbola = api.create_hyperbola(hyperbola_model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  branch = "right", asymptotes = false, tolerance = 0.1,
})
assert(hyperbola.created)
local curve = hyperbola_model.entries[1].object:shape()[1]
assert(#curve >= 1 and #curve < 256)
for index, spline in ipairs(curve) do
  assert(spline.type == "spline" and #spline == 4)
  if index > 1 then
    assert(approximate(curve[index - 1][4].x, spline[1].x))
    assert(approximate(curve[index - 1][4].y, spline[1].y))
  end
end

local far_points = {}
for _, item in ipairs({ { 1, 0 }, { 1, 1 }, { 1, 3 }, { -1, -1 }, { -1, 2 } }) do
  local branch, parameter = item[1], item[2]
  far_points[#far_points + 1] = {
    x = branch * 5 * math.cosh(parameter),
    y = 2 * math.sinh(parameter),
  }
end
local fitted_model = new_model()
local fitted = api.create_conic(fitted_model, {
  operation = "five_points", points = far_points, group_output = false,
})
assert(fitted.created == true, fitted.error)
assert(fitted.result.properties.kind == "hyperbola")
assert(fitted.result.properties.t_max >= 3)
local fitted_curve = fitted_model.entries[1].object:shape()[1]
assert(math.abs(fitted_curve[#fitted_curve][4].y) >= math.abs(far_points[3].y) - 1e-6)
''')

    def test_public_result_schema_and_classification_properties(self):
        self.assert_lua_passes(r'''
local creators = {
  api.create_conic(new_model(), {
    operation = "steiner", points = { { x = 0, y = 0 }, { x = 40, y = 0 }, { x = 0, y = 30 } },
  }),
  api.create_ellipse_from_foci(new_model(), {
    focus_a = { x = -10, y = 0 }, focus_b = { x = 10, y = 0 }, point = { x = 0, y = 15 },
  }),
  api.create_hyperbola(new_model(), {
    operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10, asymptotes = false,
  }),
  api.create_parabolas(new_model(), {
    directrix = { p1 = { x = -20, y = 0 }, p2 = { x = 20, y = 0 } },
    foci = { { x = 0, y = 10 }, { x = 5, y = 15 } },
  }),
}
for _, result in ipairs(creators) do
  assert(result.created == true and result.status == "created")
  assert(type(result.operation) == "string")
  assert(type(result.element_count) == "number")
  assert(type(result.object_count) == "number")
  assert(type(result.metadata) == "string")
  assert(type(result.result) == "table")
end
assert(#creators[1].result.conics == 2)
assert(creators[2].result.kind == "ellipse")
assert(creators[3].result.properties.kind == "hyperbola")
assert(creators[4].result.parabola_count == 2)
assert(#creators[4].result.conics == 2)

local circle = api.conic_properties({ 1, 0, 1, 0, 0, -25 })
assert(circle.kind == "circle" and #circle.vertices == 2 and #circle.foci == 2)
local parabola = api.conic_properties({ 1, 0, 0, 0, -4, 0 })
assert(parabola.kind == "parabola" and parabola.focus and #parabola.directrices == 1)
local hyperbola = api.conic_properties({ 1, 0, -1, 0, 0, -1 })
assert(hyperbola.kind == "hyperbola" and #hyperbola.asymptotes == 2)

local circle_guides_model = new_model()
local circle_guides = api.create_conic_features(circle_guides_model, {
  operation = "guides",
  definition = { coefficients = { 1, 0, 1, 0, 0, -25 } },
  marks = true, labels = true, axes = true, vertices = true,
  foci = true, directrices = true, group_output = false,
})
assert(circle_guides.created == true, circle_guides.error)
local reference_positions = {}
local text_positions = {}
for _, entry in ipairs(circle_guides_model.entries) do
  local object = entry.object
  if object:type() == "reference" or object:type() == "text" then
    local point = object:position()
    local key = string.format("%.12g,%.12g", point.x, point.y)
    local positions = object:type() == "reference" and reference_positions or text_positions
    assert(not positions[key], "circle property guides contain coincident labels or marks")
    positions[key] = true
  end
end

local translated = api.create_hyperbola(new_model(), {
  operation = "foci_point",
  focus_a = { x = 270, y = 400 },
  focus_b = { x = 390, y = 400 },
  point = { x = 430, y = 455 },
  branch = "both", asymptotes = false,
})
assert(translated.created == true, translated.error)
assert(translated.result.properties.kind == "hyperbola")
assert(approximate(translated.result.center.x, 330))
assert(approximate(translated.result.center.y, 400))
''')

    def test_previews_cover_all_creators_and_track_selection_geometry(self):
        self.assert_lua_passes(r'''
local model = new_model()
local previews = {
  api.preview_shape_data(model, "conic", {
    operation = "steiner",
    points = { { x = 0, y = 0 }, { x = 40, y = 0 }, { x = 0, y = 30 } },
  }),
  api.preview_shape_data(model, "ellipse_from_foci", {
    focus_a = { x = -10, y = 0 }, focus_b = { x = 10, y = 0 }, point = { x = 0, y = 15 },
  }),
  api.preview_shape_data(model, "hyperbola", {
    operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10, asymptotes = true,
  }),
  api.preview_shape_data(model, "parabolas", {
    directrix = { p1 = { x = -20, y = 0 }, p2 = { x = 20, y = 0 } },
    foci = { { x = 0, y = 10 } },
  }),
  api.preview_shape_data(model, "conic_features", {
    operation = "tangent_normal",
    definition = { coefficients = { 1, 0, 1, 0, 0, -25 } },
    feature_input = { point = { x = 5, y = 0 } }, marks = true,
  }),
}
for _, preview in ipairs(previews) do
  assert(preview.created == true and preview.shape_count > 0)
end
assert(#model.entries == 0)

local selected = mark(0, 0)
local signature_model = new_model({ { object = selected, selected = 1 } })
local first = api.preview_signature(signature_model, "conic", { operation = "steiner" })
selected.matrix_value = ipe.Matrix(1, 0, 0, 1, 10, 0)
local second = api.preview_signature(signature_model, "conic", { operation = "steiner" })
assert(first ~= second)
''')

    def test_dialogs_are_dynamic_persistent_and_exception_safe(self):
        self.assert_lua_passes(r'''
local execute_hook
local execute_error
local accepted = true
ipeui.Dialog = function(_, title)
  local dialog = { title = title, values = {}, controls = {}, enabled = {}, buttons = {} }
  function dialog:add(name, kind, options)
    self.controls[name] = { kind = kind, options = options or {} }
  end
  function dialog:set(name, value) self.values[name] = value end
  function dialog:get(name) return self.values[name] end
  function dialog:setEnabled(name, value) self.enabled[name] = value end
  function dialog:addButton(name, _, action) self.buttons[name] = action end
  function dialog:execute()
    if execute_hook then execute_hook(self) end
    if execute_error then error(execute_error) end
    return accepted
  end
  return dialog
end

local selection = {
  { object = mark(0, 0), selected = 1 },
  { object = mark(60, 0), selected = 2 },
  { object = mark(0, 40), selected = 2 },
}
local model = new_model(selection)
execute_hook = function(dialog)
  assert(dialog.title == "Construct conic")
  dialog:set("operation", 2)
  dialog.controls.operation.options.action(dialog)
  assert(dialog.enabled.steiner == false)
  assert(dialog.enabled.branch == true)
  dialog:set("operation", 1)
  dialog.controls.operation.options.action(dialog)
  dialog:set("live_preview", false)
  dialog.buttons.preview()
end
local result = _G.CONICS_DIALOGS.conic(model)
assert(result.created == true, result.error)
assert(api.dialog_state.conic.live_preview == false)
assert(model.ui.finished_tools == 1)

local remembered_mode = api.dialog_state.conic.mode
local invalid_model = new_model()
execute_hook = nil
accepted = true
local invalid = _G.CONICS_DIALOGS.conic(invalid_model)
assert(invalid.created == false)
assert(api.dialog_state.conic.mode == remembered_mode)
assert(invalid_model.ui.finished_tools == 1)

local exception_model = new_model({
  { object = mark(-10, 0), selected = 2 },
  { object = mark(10, 0), selected = 2 },
  { object = mark(0, 15), selected = 1 },
})
execute_error = "dialog exploded"
local failed = _G.CONICS_DIALOGS.ellipse_from_foci(exception_model)
assert(failed.created == false and failed.status == "error")
assert_contains(failed.error, "dialog exploded")
assert(exception_model.ui.finished_tools == 1)
execute_error = nil

local cancel_model = new_model(selection)
accepted = false
local before = #cancel_model.entries
local cancelled = _G.CONICS_DIALOGS.conic(cancel_model)
assert(cancelled == false and #cancel_model.entries == before)
assert(cancel_model.ui.finished_tools == 1)
''')

    def test_aliases_are_unambiguous_and_irrelevant_values_are_not_parsed(self):
        self.assert_lua_passes(r'''
local conflict = api.create_conic(new_model(), {
  operation = "steiner", construction = "steiner",
  points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 10 } },
})
assert(conflict.status == "error")
assert_contains(conflict.error, "cannot contain both 'operation'")

local mixed = api.create_ellipse_from_foci(new_model(), {
  definition = {
    focus_a = { x = -10, y = 0 }, focus_b = { x = 10, y = 0 }, point = { x = 0, y = 15 },
  },
  focus_a = { x = -20, y = 0 },
})
assert(mixed.status == "error")
assert_contains(mixed.error, "cannot mix nested 'definition'")

local missing_center = api.create_hyperbola(new_model(), {
  operation = "parameters",
  axis = { p1 = { x = 0, y = 0 }, p2 = { x = 0, y = 10 } },
  a = 20, b = 10,
})
assert(missing_center.status == "error")
assert_contains(missing_center.error, "center is required")

local ambiguous_definition = api.create_conic_features(new_model(), {
  operation = "tangent",
  definition = {
    coefficients = { 1, 0, 1, 0, 0, -25 },
    points = {
      { x = 5, y = 0 }, { x = 0, y = 5 }, { x = -5, y = 0 },
      { x = 0, y = -5 }, { x = 3, y = 4 },
    },
  },
  feature_input = { point = { x = 5, y = 0 } },
})
assert(ambiguous_definition.status == "error")
assert_contains(ambiguous_definition.error, "cannot combine coefficients")

local no_guides_model = new_model()
local no_guides = api.create_conic_features(no_guides_model, {
  operation = "properties",
  definition = { coefficients = { 1, 0, 1, 0, 0, -25 } },
  create_guides = false,
  line_length = "irrelevant-and-invalid",
})
assert(no_guides.status == "inspected" and #no_guides_model.entries == 0)

local conflicting_guides = api.create_conic_features(new_model(), {
  operation = "properties",
  definition = { coefficients = { 1, 0, 1, 0, 0, -25 } },
  create_guides = false, guides = true,
})
assert(conflicting_guides.status == "error")
assert_contains(conflicting_guides.error, "cannot contain both 'create_guides'")

local extra_coefficient = api.inspect_conic(new_model(), {
  coefficients = { 1, 0, 1, 0, 0, -25, 99 },
})
assert(extra_coefficient.status == "error")
assert_contains(extra_coefficient.error, "exactly six conic coefficients")
''')

    def test_metadata_schema_rejects_unknown_versions_roles_and_incomplete_auxiliaries(self):
        self.assert_lua_passes(r'''
local future = segment(-1, 0, 1, 0)
future.custom = "conics:v2;role=curve"
local ok_future, future_error = pcall(api.parse_conic_metadata, future)
assert(ok_future == false)
assert_contains(tostring(future_error), "Unsupported Conics metadata version")

local unknown_role = segment(-1, 0, 1, 0)
unknown_role.custom = "conics:v1;role=banana;id=c1;kind=ellipse;source=test;trusted=true"
local ok_role, role_error = pcall(api.parse_conic_metadata, unknown_role)
assert(ok_role == false)
assert_contains(tostring(role_error), "unsupported object role")

local incomplete = segment(-1, 0, 1, 0)
incomplete.custom = "conics:v1;role=asymptote;id=c1;kind=hyperbola;source=test"
local ok_incomplete, incomplete_error = pcall(api.parse_conic_metadata, incomplete)
assert(ok_incomplete == false)
assert_contains(tostring(incomplete_error), "not marked as trusted")

local grouped_model = new_model()
local grouped = api.create_hyperbola(grouped_model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 20, b = 10,
  branch = "both", asymptotes = true,
})
assert(grouped.created and #grouped_model.entries == 1)
local coefficients, information = api.parse_conic_metadata(grouped_model.entries[1].object)
assert(coefficients == nil and information.status == "auxiliary")
assert(information.role == "group")
''')

    def test_bounds_padding_and_scaled_exact_ellipses(self):
        self.assert_lua_passes(r'''
local far_points = {}
for _, item in ipairs({ { 1, 0 }, { 1, 1 }, { 1, 3 }, { -1, -1 }, { -1, 2 } }) do
  far_points[#far_points + 1] = {
    x = item[1] * 5 * math.cosh(item[2]), y = 2 * math.sinh(item[2]),
  }
end
local plain = api.create_conic(new_model(), {
  operation = "five_points", points = far_points, padding = 0, group_output = false,
})
local padded = api.create_conic(new_model(), {
  operation = "five_points", points = far_points, padding = 40, group_output = false,
})
assert(plain.created and padded.created)
assert(padded.result.properties.t_max > plain.result.properties.t_max)

local bounded = api.create_conic(new_model(), {
  operation = "focus_directrix_point",
  focus = { x = 0, y = 10 },
  directrix = { p1 = { x = -20, y = -10 }, p2 = { x = 20, y = -10 } },
  point_on_conic = { x = 0, y = 0 },
  bounds = { left = -200, right = 200, bottom = -50, top = 250 },
  padding = 5,
})
assert(bounded.created == true, bounded.error)
assert(bounded.result.properties.kind == "parabola")
assert(bounded.result.properties.render_extent >= 205)

local conflicting_extent = api.create_conic(new_model(), {
  operation = "focus_directrix_point",
  focus = { x = 0, y = 10 },
  directrix = { p1 = { x = -20, y = -10 }, p2 = { x = 20, y = -10 } },
  point_on_conic = { x = 0, y = 0 }, extent = 100,
  bounds = { left = -200, right = 200, bottom = -50, top = 250 },
})
assert(conflicting_extent.status == "error")
assert_contains(conflicting_extent.error, "both 'extent' and 'bounds'")

assert(api.stable_acosh(1e300) > 690)

for _, magnitude in ipairs({ 1e-200, 1e200 }) do
  local model = new_model()
  local result = api.create_conic(model, {
    operation = "steiner", mode = "circumellipse",
    points = {
      { x = -magnitude, y = 0 }, { x = magnitude, y = 0 },
      { x = 0, y = magnitude },
    },
  })
  assert(result.created == true, result.error)
  assert(model.entries[1].object:shape()[1].type == "ellipse")
  assert(result.result.conics[1].properties.major_radius > 0)
end
''')

    def test_single_transaction_undo_redo_and_affine_metadata_transform(self):
        self.assert_lua_passes(r'''
local model, _, document = new_model()
local created = api.create_ellipse_from_foci(model, {
  focus_a = { x = -10, y = 0 }, focus_b = { x = 10, y = 0 }, point = { x = 0, y = 15 },
})
assert(created.created and #model.registrations == 1 and #model.entries == 1)
model.registration:undo(document)
assert(#model.entries == 0)
model.registration:redo(document)
assert(#model.entries == 1 and model.entries[1].selected == 1)

local ellipse = model.entries[1].object
ellipse.matrix_value = ipe.Matrix(2, 0, 0, 1, 10, 0)
local inspected = api.inspect_conic(model, {})
assert(inspected.status == "inspected", inspected.error)
assert(approximate(inspected.result.properties.center.x, 10))
local transformed_point = { x = 10, y = 15 }
local value, magnitude = api.evaluate_conic(inspected.result.coefficients, transformed_point)
assert(math.abs(value) <= 1e-8 * math.max(1, magnitude))
''')

    def test_public_api_is_explicit_instead_of_exporting_runtime_internals(self):
        self.assert_lua_passes(r'''
assert(type(api.public_functions) == "table")
for _, name in ipairs(api.public_functions) do assert(type(api[name]) == "function", name) end
for _, internal in ipairs({
  "clone_table", "make_segment", "register_creation", "selected_objects",
  "start_dialog_preview", "object_preview_shapes",
}) do
  assert(api[internal] == nil, internal)
end
''')

if __name__ == "__main__":
    unittest.main()
