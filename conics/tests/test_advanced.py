import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "conics.lua"
RUNTIME = ROOT / "tests/conics_runtime.lua"


class ConicsAdvancedTest(unittest.TestCase):
    maxDiff = None

    def assert_lua_passes(self, body: str) -> None:
        script = (
            f"CONICS_PATH={json.dumps(str(SOURCE))}\n"
            + RUNTIME.read_text(encoding="utf-8")
            + "\n"
            + body
        )
        completed = subprocess.run(
            ["lua5.4", "-e", script],
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_new_exact_fitted_dual_and_mixed_constructions(self) -> None:
        self.assert_lua_passes(r'''
local samples = {}
for index = 0, 15 do
  local angle = 2 * math.pi * index / 16
  samples[#samples + 1] = {
    x = 12 + 8 * math.cos(angle),
    y = -7 + 3 * math.sin(angle),
  }
end
local fitted, diagnostics = api.conic_coefficients_from_points(samples)
local fitted_properties = api.conic_properties(fitted)
assert(fitted_properties.kind == "ellipse")
assert(diagnostics.sample_count == 16)
assert(diagnostics.rms_residual < 1e-10)
assert(approximate(fitted_properties.center.x, 12, 1e-7))
assert(approximate(fitted_properties.center.y, -7, 1e-7))
assert(approximate(fitted_properties.major_radius, 8, 1e-7))
assert(approximate(fitted_properties.minor_radius, 3, 1e-7))

local noisy_samples = {}
local noise = { 0.018, -0.024, 0.011, -0.015, 0.027, -0.009, 0.014, -0.021 }
for index = 0, 31 do
  local angle = 2 * math.pi * index / 32
  local radial_noise = noise[index % #noise + 1]
  noisy_samples[#noisy_samples + 1] = {
    x = 12 + (8 + radial_noise) * math.cos(angle),
    y = -7 + (3 + 0.5 * radial_noise) * math.sin(angle),
  }
end
local noisy_fitted, noisy_diagnostics = api.conic_coefficients_from_points(noisy_samples)
local noisy_properties = api.conic_properties(noisy_fitted)
assert(noisy_properties.kind == "ellipse")
assert(noisy_diagnostics.sample_count == 32)
assert(noisy_diagnostics.rms_residual > 0)
assert(noisy_diagnostics.rms_residual < 0.01)
assert(approximate(noisy_properties.center.x, 12, 0.02))
assert(approximate(noisy_properties.center.y, -7, 0.02))
assert(approximate(noisy_properties.major_radius, 8, 0.03))
assert(approximate(noisy_properties.minor_radius, 3, 0.03))

local tangent_lines = {}
for index = 0, 4 do
  local angle = 2 * math.pi * index / 5
  tangent_lines[#tangent_lines + 1] = {
    a = math.cos(angle), b = math.sin(angle), c = -10,
  }
end
local envelope = api.conic_coefficients_from_five_lines(tangent_lines)
local envelope_properties = api.conic_properties(envelope)
assert(envelope_properties.kind == "circle")
assert(approximate(envelope_properties.major_radius, 10, 1e-7))
for _, line in ipairs(tangent_lines) do
  assert(#api.conic_line_intersections(envelope, line) == 1)
end

local mixed = api.conic_coefficients_from_constraints({
  { type = "tangent", point = { x = 10, y = 0 },
    line = { a = 1, b = 0, c = -10 } },
  { point = { x = 0, y = 10 } },
  { point = { x = -10, y = 0 } },
  { point = { x = 0, y = -10 } },
})
assert(api.conic_properties(mixed).kind == "circle")
local tangent = api.conic_tangent_normal(mixed, { x = 10, y = 0 }).tangent
assert(math.abs(tangent.direction.x) < 1e-8)

for _, case in ipairs({
  { eccentricity = 0.5, kind = "ellipse" },
  { eccentricity = 1, kind = "parabola" },
  { eccentricity = 2, kind = "hyperbola" },
}) do
  local coefficients = api.conic_coefficients_for_focus_directrix(
    { x = 0, y = 5 }, { a = 0, b = 1, c = 5 }, case.eccentricity
  )
  assert(api.classify_conic(coefficients).kind == case.kind)
end
''')

    def test_special_constructors_and_all_degenerate_loci(self) -> None:
        self.assert_lua_passes(r'''
local ellipse = api.ellipse_from_center_axes(
  { x = 2, y = 3 }, { x = 7, y = 3 }, { x = 2, y = 5 }
)
local ellipse_properties = api.conic_properties(api.ellipse_coefficients(ellipse))
assert(approximate(ellipse_properties.major_radius, 5))
assert(approximate(ellipse_properties.minor_radius, 2))

local parabola, directrix = api.parabola_from_vertex_focus(
  { x = 4, y = -3 }, { x = 4, y = 2 }
)
local parabola_properties = api.conic_properties(parabola)
assert(parabola_properties.kind == "parabola")
assert(approximate(parabola_properties.vertex.x, 4))
assert(approximate(parabola_properties.vertex.y, -3))
assert(approximate(directrix.point.y, -8))

local hyperbola = api.hyperbola_from_asymptotes_point(
  { a = 1, b = -1, c = 0 }, { a = 1, b = 1, c = 0 }, { x = 5, y = 3 }
)
assert(api.conic_properties(hyperbola).kind == "hyperbola")
local value, magnitude = api.evaluate_conic(hyperbola, { x = 5, y = 3 })
assert(math.abs(value) < 1e-10 * math.max(1, magnitude))

local cases = {
  { api.degenerate_conic_from_lines({
      { a = 1, b = 0, c = 0 }, { a = 0, b = 1, c = 0 },
    }), "intersecting_lines" },
  { api.degenerate_conic_from_lines({
      { a = 1, b = 0, c = -2 }, { a = 1, b = 0, c = 2 },
    }), "parallel_lines" },
  { api.degenerate_conic_from_lines({ { a = 1, b = 0, c = -2 } }), "double_line" },
  { { 0, 0, 0, 1, 0, -2 }, "single_line" },
  { api.degenerate_point_conic({ x = 3, y = -4 }), "point" },
  { { 0, 0, 0, 0, 0, 1 }, "empty" },
}
for _, case in ipairs(cases) do
  local properties = api.conic_properties(case[1])
  assert(properties.kind == "degenerate")
  assert(properties.subtype == case[2], properties.subtype)
end
''')

    def test_poles_tangents_focal_chords_and_conic_intersections(self) -> None:
        self.assert_lua_passes(r'''
local circle = { 1, 0, 1, 0, 0, -25 }
local outside = api.tangents_from_point(circle, { x = 10, y = 0 })
assert(outside.count == 2)
assert(approximate(outside.contact_points[1].x, 2.5, 1e-7))
assert(approximate(outside.contact_points[2].x, 2.5, 1e-7))
assert(api.tangents_from_point(circle, { x = 5, y = 0 }).count == 1)
assert(api.tangents_from_point(circle, { x = 0, y = 0 }).count == 0)

local polar = api.conic_polar_line(circle, { x = 10, y = 0 })
local pole = api.conic_pole(circle, polar)
assert(pole.finite)
assert(approximate(pole.point.x, 10, 1e-8))
assert(approximate(pole.point.y, 0, 1e-8))
local translated_circle = { 1, 0, 1, -600, -800, 241900 }
local anchored_polar = api.conic_polar_line(translated_circle, { x = 440, y = 455 })
assert(math.sqrt((anchored_polar.point.x - 300)^2 + (anchored_polar.point.y - 400)^2) < 90)
local anchored_tangents = api.tangents_from_point(translated_circle, { x = 470, y = 400 })
assert(math.sqrt(
  (anchored_tangents.chord_of_contact.point.x - 300)^2
    + (anchored_tangents.chord_of_contact.point.y - 400)^2
) < 90)
local infinite_pole = api.conic_pole(circle, { a = 0, b = 1, c = 0 })
assert(infinite_pole.finite == false and infinite_pole.at_infinity == true)

local chord = api.focal_chord(
  { 1 / 25, 0, 1 / 9, 0, 0, -1 }, { x = 5, y = 0 }
)
assert(chord.count == 2)
assert(approximate(chord.endpoints[1].y, 0, 1e-8))
assert(approximate(chord.endpoints[2].y, 0, 1e-8))

local two = api.conic_conic_intersections(
  circle, { 1, 0, 1, -6, 0, -16 }
)
assert(#two == 2, "expected two circle intersections, got " .. #two)
local tangent = api.conic_conic_intersections(
  circle, { 1, 0, 1, -20, 0, 75 }
)
assert(#tangent == 1, "expected one tangent intersection, got " .. #tangent)
local none = api.conic_conic_intersections(
  circle, { 1, 0, 1, -30, 0, 200 }
)
assert(#none == 0, "expected no disjoint-circle intersections, got " .. #none)
local four = api.conic_conic_intersections(
  circle, { 1 / 36, 0, 1 / 9, 0, 0, -1 }
)
assert(#four == 4, "expected four circle-ellipse intersections, got " .. #four)
local two_parabolas = api.conic_conic_intersections(
  { 1, 0, 0, 0, -1, 0 }, { 1, 0, 0, 0, 1, -2 }
)
assert(#two_parabolas == 2, "expected two parabola intersections, got " .. #two_parabolas)
local coincident = api.conic_conic_intersections(circle, { -2, 0, -2, 0, 0, 50 })
assert(coincident.infinite and coincident.coincident)

local function translated_circle(center_x, center_y, radius)
  return {
    1, 0, 1, -2 * center_x, -2 * center_y,
    center_x * center_x + center_y * center_y - radius * radius,
  }
end
for _, scale_case in ipairs({
  { center_x = 1e6, center_y = -2e6, radius = 10, separation = 12 },
  { center_x = 1e-6, center_y = -2e-6, radius = 1e-7, separation = 1.2e-7 },
}) do
  local scaled = api.conic_conic_intersections(
    translated_circle(scale_case.center_x, scale_case.center_y, scale_case.radius),
    translated_circle(scale_case.center_x + scale_case.separation,
      scale_case.center_y, scale_case.radius)
  )
  assert(#scaled == 2, "expected two scale-stress intersections, got " .. #scaled)
end
''')

    def test_workflows_guides_trim_and_fitted_replacement_are_transactional(self) -> None:
        self.assert_lua_passes(r'''
local ellipse_result = api.create_ellipse(new_model(), {
  operation = "center_axes",
  center = { x = 0, y = 0 },
  first_endpoint = { x = 10, y = 0 },
  second_endpoint = { x = 0, y = 5 },
})
assert(ellipse_result.created, ellipse_result.error)

local hyperbola_result = api.create_hyperbola(new_model(), {
  operation = "asymptotes_point",
  asymptote_a = { a = 1, b = -1, c = 0 },
  asymptote_b = { a = 1, b = 1, c = 0 },
  point = { x = 5, y = 3 },
  asymptotes = true,
})
assert(hyperbola_result.created, hyperbola_result.error)

local parabola_result = api.create_parabola(new_model(), {
  operation = "vertex_focus",
  vertex = { x = 0, y = 0 }, focus = { x = 0, y = 4 }, extent = 40,
})
assert(parabola_result.created, parabola_result.error)

local guides = api.create_conic_features(new_model(), {
  operation = "guides",
  definition = { coefficients = { 1 / 100, 0, 1 / 25, 0, 0, -1 } },
  axes = true, vertices = true, foci = true, directrices = true,
  latus_recta = true, auxiliary_circles = true, director_circle = true,
  general_equation = true, canonical_equation = true, parameters = true,
  group_output = false,
})
assert(guides.created, guides.error)
assert(guides.element_count >= 15)
local equation_count = 0
for _, entry in ipairs(guides.result.properties.equations and { 1 } or {}) do
  equation_count = equation_count + entry
end
assert(equation_count == 1)

local native = ipe.Path({}, { { type = "ellipse"; ipe.Matrix(5, 0, 0, 5, 0, 0) } })
local trim_model, _, trim_document = new_model({
  { object = native, selected = 1, layer = "alpha" },
  { object = mark(5, 0), selected = 2, layer = "alpha" },
  { object = mark(0, 5), selected = 2, layer = "alpha" },
})
local trimmed = api.create_conic_features(trim_model, {
  operation = "conic_arc", arc_mode = "shorter", replace_original = true,
})
assert(trimmed.created, trimmed.error)
assert(trim_model.entries[1].object:shape()[1][1].type == "arc")
trim_model.registration:undo(trim_document)
assert(trim_model.entries[1].object == native)
trim_model.registration:redo(trim_document)
assert(trim_model.entries[1].object:shape()[1][1].type == "arc")

local rough = ipe.Path({}, { { type = "curve", closed = true;
  { type = "spline"; { x = 10, y = 0 }, { x = 10, y = 5.5 },
    { x = 5.5, y = 10 }, { x = 0, y = 10 } },
  { type = "spline"; { x = 0, y = 10 }, { x = -5.5, y = 10 },
    { x = -10, y = 5.5 }, { x = -10, y = 0 } },
  { type = "spline"; { x = -10, y = 0 }, { x = -10, y = -5.5 },
    { x = -5.5, y = -10 }, { x = 0, y = -10 } },
  { type = "spline"; { x = 0, y = -10 }, { x = 5.5, y = -10 },
    { x = 10, y = -5.5 }, { x = 10, y = 0 } },
} })
local fit_model, _, fit_document = new_model({
  { object = rough, selected = 1, layer = "alpha" },
})
local replacement = api.create_conic_features(fit_model, {
  operation = "fit_replace_path", expected_kind = "ellipse",
})
assert(replacement.created, replacement.error)
assert(replacement.result.fit.rms_residual < 5e-3)
fit_model.registration:undo(fit_document)
assert(fit_model.entries[1].object == rough)
fit_model.registration:redo(fit_document)
assert(fit_model.entries[1].object ~= rough)
''')

    def test_every_new_constructor_has_a_public_workflow(self) -> None:
        self.assert_lua_passes(r'''
local samples = {}
for index = 0, 11 do
  local angle = 2 * math.pi * index / 12
  samples[#samples + 1] = {
    x = 4 + 12 * math.cos(angle),
    y = -3 + 6 * math.sin(angle),
  }
end
local fitted = api.create_conic(new_model(), {
  operation = "fit_points", points = samples, expected_kind = "ellipse",
})
assert(fitted.created and fitted.result.fit.sample_count == 12, fitted.error)

local tangent_lines = {}
for index = 0, 4 do
  local angle = 2 * math.pi * index / 5
  tangent_lines[#tangent_lines + 1] = {
    a = math.cos(angle), b = math.sin(angle), c = -10,
  }
end
local five_tangents = api.create_conic(new_model(), {
  operation = "five_tangents", lines = tangent_lines,
})
assert(five_tangents.created, five_tangents.error)
assert(five_tangents.result.type == "five-tangent-conic")

local mixed = api.create_conic(new_model(), {
  operation = "five_conditions",
  constraints = {
    { type = "tangent", point = { x = 10, y = 0 },
      line = { a = 1, b = 0, c = -10 } },
    { point = { x = 0, y = 10 } },
    { point = { x = -10, y = 0 } },
    { point = { x = 0, y = -10 } },
  },
})
assert(mixed.created, mixed.error)
assert(mixed.result.type == "mixed-condition-conic")

for _, case in ipairs({
  { eccentricity = 0.5, kind = "ellipse" },
  { eccentricity = 1, kind = "parabola" },
  { eccentricity = 2, kind = "hyperbola" },
}) do
  local result = api.create_conic(new_model(), {
    operation = "focus_directrix_eccentricity",
    focus = { x = 0, y = 5 },
    directrix = { a = 0, b = 1, c = 5 },
    eccentricity = case.eccentricity,
  })
  assert(result.created, result.error)
  assert(result.result.properties.kind == case.kind)
end

for _, case in ipairs({
  { operation = "degenerate_line_pair", lines = {
      { a = 1, b = 0, c = 0 }, { a = 0, b = 1, c = 0 },
    }, subtype = "intersecting_lines", elements = 2 },
  { operation = "degenerate_double_line", lines = {
      { a = 1, b = 0, c = -2 },
    }, subtype = "double_line", elements = 1 },
  { operation = "degenerate_single_line", lines = {
      { a = 1, b = 0, c = -2 },
    }, subtype = "single_line", elements = 1 },
  { operation = "degenerate_point", point = { x = 3, y = 4 },
    subtype = "point", elements = 1 },
}) do
  local options = { operation = case.operation }
  if case.lines then options.lines = case.lines end
  if case.point then options.point = case.point end
  local result = api.create_conic(new_model(), options)
  assert(result.created, result.error)
  assert(result.result.properties.subtype == case.subtype)
  assert(result.element_count == case.elements)
end
local empty_model = new_model()
local empty = api.create_conic(empty_model, { operation = "degenerate_empty" })
assert(empty.created == false and empty.status == "empty")
assert(#empty_model:page() == 0)

assert(api.create_ellipse == api.create_ellipse_from_foci)
assert(api.create_parabola == api.create_parabolas)
''')

    def test_every_new_feature_has_a_public_workflow(self) -> None:
        self.assert_lua_passes(r'''
local circle = { 1, 0, 1, 0, 0, -100 }
local outside_tangents = api.create_conic_features(new_model(), {
  operation = "tangents_from_point",
  definition = { coefficients = circle },
  feature_input = { point = { x = 20, y = 0 } },
  chord = true, marks = true, group_output = false,
})
assert(outside_tangents.created, outside_tangents.error)
assert(outside_tangents.result.tangent_count == 2)
assert(outside_tangents.element_count == 5)

local pole = api.create_conic_features(new_model(), {
  operation = "pole", definition = { coefficients = circle },
  feature_input = { line = { a = 1, b = 0, c = -5 } },
  marks = true, labels = true, group_output = false,
})
assert(pole.created and pole.result.finite, pole.error)
assert(approximate(pole.result.point.x, 20))

local focal = api.create_conic_features(new_model(), {
  operation = "focal_chord",
  definition = { coefficients = { 1 / 100, 0, 1 / 36, 0, 0, -1 } },
  feature_input = { point = { x = 10, y = 0 } }, marks = true,
})
assert(focal.created, focal.error)
assert(#focal.result.endpoints == 2)

local intersections = api.create_conic_features(new_model(), {
  operation = "conic_intersections", definition = { coefficients = circle },
  feature_input = {
    second_coefficients = { 1, 0, 1, -12, 0, -64 },
  },
  marks = false,
})
assert(intersections.created == false and intersections.status == "computed")
assert(intersections.result.intersection_count == 2)

local disjoint = api.create_conic_features(new_model(), {
  operation = "conic_intersections", definition = { coefficients = circle },
  feature_input = {
    second_coefficients = { 1, 0, 1, -60, 0, 800 },
  },
})
assert(disjoint.created == false and disjoint.status == "empty")

local coincident = api.create_conic_features(new_model(), {
  operation = "conic_intersections", definition = { coefficients = circle },
  feature_input = { second_coefficients = { -2, 0, -2, 0, 0, 200 } },
})
assert(coincident.created == false and coincident.status == "infinite")

local parabola = { 1, 0, 0, 0, -4, 0 }
local parabola_arc = api.create_conic_features(new_model(), {
  operation = "conic_arc", definition = { coefficients = parabola },
  feature_input = { points = { { x = -4, y = 4 }, { x = 4, y = 4 } } },
  replace_original = false,
})
assert(parabola_arc.created, parabola_arc.error)
assert(parabola_arc.result.kind == "parabola")

local hyperbola = { 1 / 25, 0, -1 / 9, 0, 0, -1 }
local hyperbola_arc = api.create_conic_features(new_model(), {
  operation = "conic_arc", definition = { coefficients = hyperbola },
  feature_input = { points = { { x = 5, y = 0 }, { x = 10, y = 3 * math.sqrt(3) } } },
  replace_original = false,
})
assert(hyperbola_arc.created, hyperbola_arc.error)
assert(hyperbola_arc.result.kind == "hyperbola")
''')

    def test_invalid_new_inputs_fail_cleanly_without_mutation(self) -> None:
        self.assert_lua_passes(r'''
local invalid_calls = {
  function()
    return api.create_conic(new_model(), {
      operation = "five_tangents",
      lines = { { a = 1, b = 0, c = 0 } },
    })
  end,
  function()
    return api.create_conic(new_model(), {
      operation = "five_conditions",
      constraints = { { point = { x = 0, y = 0 } } },
    })
  end,
  function()
    return api.create_ellipse(new_model(), {
      operation = "center_axes", center = { x = 0, y = 0 },
      first_endpoint = { x = 5, y = 0 }, second_endpoint = { x = 5, y = 5 },
    })
  end,
  function()
    return api.create_hyperbola(new_model(), {
      operation = "asymptotes_point",
      asymptote_a = { a = 1, b = 0, c = 0 },
      asymptote_b = { a = 1, b = 0, c = -1 },
      point = { x = 2, y = 3 },
    })
  end,
  function()
    return api.create_parabola(new_model(), {
      operation = "vertex_focus", vertex = { x = 1, y = 1 }, focus = { x = 1, y = 1 },
    })
  end,
}
for _, callback in ipairs(invalid_calls) do
  local model = new_model()
  local result = callback(model)
  assert(result.created == false and result.status == "error")
  assert(type(result.error) == "string" and result.error ~= "")
  assert(#model:page() == 0)
end

local hyperbola = { 1 / 25, 0, -1 / 9, 0, 0, -1 }
local ok, message = pcall(api.conic_arc_definition, hyperbola, { x = 5, y = 0 }, { x = -5, y = 0 })
assert(ok == false)
assert_contains(tostring(message), "same connected branch")
''')


if __name__ == "__main__":
    unittest.main()
