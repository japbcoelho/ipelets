import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CIRCLES = ROOT / "circles.lua"


LUA_IPE_STUB = r'''
ipe = {}
ipeui = {}

function ipe.Vector(x, y)
  return { x = x, y = y }
end

local matrix_mt = {}
matrix_mt.__index = matrix_mt
matrix_mt.__mul = function(left, right)
  if right.x == nil or right.y == nil then
    return ipe.Matrix(
      left.a * right.a + left.b * right.c,
      left.a * right.b + left.b * right.d,
      left.c * right.a + left.d * right.c,
      left.c * right.b + left.d * right.d,
      left.a * right.e + left.b * right.f + left.e,
      left.c * right.e + left.d * right.f + left.f
    )
  end
  return ipe.Vector(
    left.a * right.x + left.b * right.y + left.e,
    left.c * right.x + left.d * right.y + left.f
  )
end
function matrix_mt:coeff() return self.a, self.c, self.b, self.d, self.e, self.f end

function ipe.Matrix(a, b, c, d, e, f)
  return setmetatable({
    a = a or 1,
    b = b or 0,
    c = c or 0,
    d = d or 1,
    e = e or 0,
    f = f or 0,
  }, matrix_mt)
end

local function new_object(kind, shape, position, attributes, symbol, arrows)
  local object = {
    _kind = kind,
    _shape = shape,
    _position = position,
    _attributes = attributes,
    _symbol = symbol,
    _arrows = arrows,
    _custom = "",
  }
  function object:type() return self._kind end
  function object:shape() return self._shape end
  function object:position() return self._position end
  function object:symbol() return self._symbol end
  function object:matrix() return ipe.Matrix() end
  function object:getCustom() return self._custom end
  function object:setCustom(value) self._custom = value end
  return object
end

function ipe.Path(attributes, shape, arrows)
  return new_object("path", shape, nil, attributes, nil, arrows)
end

function ipe.Reference(attributes, symbol, position)
  return new_object("reference", nil, position, attributes, symbol)
end

function ipe.Text(attributes, _, position)
  return new_object("text", nil, position, attributes)
end

function ipe.Arc(_, alpha, beta)
  return { start = ipe.Vector(math.cos(alpha), math.sin(alpha)),
    finish = ipe.Vector(math.cos(beta), math.sin(beta)) }
end

function new_test_model(entries, active, primary, visible)
  local page = {
    _entries = entries or {},
    _active = active or "alpha",
    _primary = primary,
    _visible = visible,
  }
  function page:objects()
    local index = 0
    return function()
      index = index + 1
      local entry = self._entries[index]
      if not entry then return nil end
      return index, entry.object, entry.selected, entry.layer
    end
  end
  function page:visible() return self._visible ~= false end
  function page:primarySelection() return self._primary end
  function page:active() return self._active end

  local model = { pno = 1, vno = 1, _page = page }
  function model:page() return self._page end
  function model:register(transaction) self.transaction = transaction end
  function model:warning(title, detail)
    self.warnings = self.warnings or {}
    self.warnings[#self.warnings + 1] = { title = title, detail = detail }
    self.last_warning = { title = title, detail = detail }
  end
  return model
end
'''


class CirclesGeometryRegressionTest(unittest.TestCase):
    def run_lua(self, body: str) -> subprocess.CompletedProcess[str]:
        script = (
            LUA_IPE_STUB
            + f"\ndofile({str(CIRCLES)!r})\n"
            + "local GEOMETRY = assert(_G.CIRCLES)\n"
            + body
        )
        return subprocess.run(
            ["lua5.4", "-e", script],
            check=False,
            text=True,
            capture_output=True,
        )

    def assert_lua_ok(self, body: str) -> None:
        completed = self.run_lua(body)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_three_point_tangent_solver_is_scale_invariant(self):
        self.assert_lua_ok(r'''
local failures = {}
for _, scale in ipairs({ 1e-6, 10000 }) do
  local ok, message = pcall(function()
    local solutions = GEOMETRY.tangent_circles_from_constraints({
      { type = "point", point = { x = 0, y = 0 } },
      { type = "point", point = { x = scale, y = 0 } },
      { type = "point", point = { x = 0, y = scale } },
    })
    assert(#solutions == 1, string.format(
      "expected one circumcircle, got %d",
      #solutions
    ))

    local expected = scale / 2
    local expected_radius = scale / math.sqrt(2)
    local tolerance = math.max(scale * 1e-6, 1e-12)
    local circle = solutions[1]
    assert(math.abs(circle.center.x - expected) <= tolerance, "wrong center x")
    assert(math.abs(circle.center.y - expected) <= tolerance, "wrong center y")
    assert(math.abs(circle.radius - expected_radius) <= tolerance, "wrong radius")
  end)
  if not ok then
    failures[#failures + 1] = string.format("scale %.17g: %s", scale, tostring(message))
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
''')

    def test_internal_tangency_rejects_coincident_reference_circle(self):
        self.assert_lua_ok(r'''
local ok = pcall(function()
  GEOMETRY.tangent_circles_from_constraints({
    { type = "point", point = { x = 10, y = 0 } },
    { type = "point", point = { x = 0, y = 10 } },
    {
      type = "circle",
      circle = { center = { x = 0, y = 0 }, radius = 10 },
      sign = -1,
    },
  })
end)
assert(not ok, "a coincident circle is not a valid internal tangency solution")
''')

    def test_explicit_inversion_uses_active_layer_not_unrelated_selection(self):
        self.assert_lua_ok(r'''
local selected_segment = ipe.Path({}, {
  {
    type = "curve",
    closed = false,
    { type = "segment", ipe.Vector(-5, 3), ipe.Vector(5, 3) },
  },
})
local model = new_test_model({
  { object = selected_segment, selected = true, layer = "beta" },
}, "alpha")

local result = GEOMETRY.create_inversion_radical(model, {
  operation = "invert_point",
  point = { x = 20, y = 0 },
  inversion_circle = { center = { x = 0, y = 0 }, radius = 10 },
  labels = false,
})

assert(result.created, result.error)
assert(model.transaction.layer == "alpha", string.format(
  "explicit construction should use active layer alpha, got %s",
  tostring(model.transaction.layer)
))
''')

    def test_perpendicular_operation_alias_is_case_insensitive(self):
        self.assert_lua_ok(r'''
local model = new_test_model({}, "alpha")
local result = GEOMETRY.create_tangent_lines(model, {
  operation = "Perpendicular",
  circle = { center = { x = 0, y = 0 }, radius = 10 },
  line = { p1 = { x = -20, y = 0 }, p2 = { x = 20, y = 0 } },
  tangent_points = false,
  labels = false,
  line_length = 40,
})

assert(result.created, result.error)
assert(result.mode == "perpendicular", string.format(
  "expected perpendicular mode, got %s",
  tostring(result.mode)
))
for _, tangent in ipairs(result.tangents) do
  assert(tangent.kind == "perpendicular", "tangent geometry should be perpendicular")
end
''')

    def test_three_line_public_flow_keeps_four_solutions_at_every_scale(self):
        self.assert_lua_ok(r'''
local failures = {}
for _, scale in ipairs({ 1, 1e-3, 1e-6 }) do
  local model = new_test_model({}, "alpha")
  local result = GEOMETRY.create_tangent_circles(model, {
    operation = "three_lines",
    lines = {
      { p1 = { x = 0, y = 0 }, p2 = { x = scale, y = 0 } },
      { p1 = { x = 0, y = 0 }, p2 = { x = 0, y = scale } },
      { p1 = { x = scale, y = 0 }, p2 = { x = 0, y = scale } },
    },
    line_side = "both",
    max_solutions = 16,
    center_marks = false,
    tangent_points = true,
    labels = false,
  })
  if not result.created or result.circle_count ~= 4 then
    failures[#failures + 1] = string.format(
      "scale %.17g: created=%s, expected 4 circles, got %s (%s)",
      scale,
      tostring(result.created),
      tostring(result.circle_count),
      tostring(result.error)
    )
  end
  for index, circle in ipairs(result.circles or {}) do
    if #(circle.tangency_points or {}) ~= 3 then
      failures[#failures + 1] = string.format(
        "scale %.17g, circle %d: expected 3 distinct tangency points, got %d",
        scale,
        index,
        #(circle.tangency_points or {})
      )
    end
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
''')

    def test_circumcircle_and_arc_are_scale_and_translation_stable(self):
        self.assert_lua_ok(r'''
local failures = {}
local cases = {
  { origin = 0, scale = 1 },
  { origin = 0, scale = 1e-3 },
  { origin = 0, scale = 1e-6 },
  { origin = 1e9, scale = 1 },
  { origin = 1e12, scale = 1 },
}

for _, case in ipairs(cases) do
  local origin = case.origin
  local scale = case.scale
  local a = { x = origin, y = origin }
  local b = { x = origin + scale, y = origin }
  local c = { x = origin, y = origin + scale }
  local ok, message = pcall(function()
    local circle = GEOMETRY.circle_through_three_points(a, b, c)
    local expected_center = origin + scale / 2
    local expected_radius = scale / math.sqrt(2)
    local tolerance = math.max(scale * 1e-8, math.abs(origin) * 3e-15, 1e-15)
    assert(math.abs(circle.center.x - expected_center) <= tolerance, "wrong center x")
    assert(math.abs(circle.center.y - expected_center) <= tolerance, "wrong center y")
    assert(math.abs(circle.radius - expected_radius) <= tolerance, "wrong radius")

    local arc = GEOMETRY.arc_through_three_points(a, b, c)
    assert(arc.orientation == "counterclockwise", "wrong arc orientation")
    assert(math.abs(arc.center.x - expected_center) <= tolerance, "wrong arc center x")
    assert(math.abs(arc.center.y - expected_center) <= tolerance, "wrong arc center y")
    assert(math.abs(arc.radius - expected_radius) <= tolerance, "wrong arc radius")
  end)
  if not ok then
    failures[#failures + 1] = string.format(
      "origin %.17g, scale %.17g: %s",
      origin,
      scale,
      tostring(message)
    )
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
''')

    def test_radical_center_is_translation_stable(self):
        self.assert_lua_ok(r'''
local failures = {}
for _, origin in ipairs({ 0, 1e6, 1e9, 1e12 }) do
  local circles = {
    { center = { x = origin, y = origin }, radius = 5 },
    { center = { x = origin + 8, y = origin }, radius = 3 },
    { center = { x = origin, y = origin + 6 }, radius = 4 },
  }
  local model = new_test_model({}, "alpha")
  local result = GEOMETRY.create_inversion_radical(model, {
    operation = "radical_center",
    circles = circles,
    axes = false,
    labels = false,
  })
  local expected_x = origin + 5
  local expected_y = origin + 3.75
  local tolerance = math.max(math.abs(origin) * 3e-15, 1e-12)
  if not result.created
    or math.abs(result.result.point.x - expected_x) > tolerance
    or math.abs(result.result.point.y - expected_y) > tolerance then
    failures[#failures + 1] = string.format(
      "origin %.17g: created=%s, point=(%.17g, %.17g), error=%s",
      origin,
      tostring(result.created),
      result.result and result.result.point.x or 0 / 0,
      result.result and result.result.point.y or 0 / 0,
      tostring(result.error)
    )
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
''')

    def test_homothety_centers_are_translation_stable_for_near_equal_radii(self):
        self.assert_lua_ok(r'''
local radius_a = 1
local radius_b = 1 + 2 ^ -20
local reference = GEOMETRY.circle_homothety_centers(
  { center = { x = 0, y = 0 }, radius = radius_a },
  { center = { x = 8, y = 6 }, radius = radius_b }
)
assert(reference.external, "near-equal radii must still have an external center")

local failures = {}
for _, origin in ipairs({ 0, 1e6, 1e9, 1e12 }) do
  local translated = GEOMETRY.circle_homothety_centers(
    { center = { x = origin, y = -origin }, radius = radius_a },
    { center = { x = origin + 8, y = -origin + 6 }, radius = radius_b }
  )
  local tolerance = math.max(math.abs(origin) * 3e-15, 1e-8)
  local expected_internal_x = origin + reference.internal.x
  local expected_internal_y = -origin + reference.internal.y
  local expected_external_x = origin + reference.external.x
  local expected_external_y = -origin + reference.external.y
  if math.abs(translated.internal.x - expected_internal_x) > tolerance
    or math.abs(translated.internal.y - expected_internal_y) > tolerance
    or math.abs(translated.external.x - expected_external_x) > tolerance
    or math.abs(translated.external.y - expected_external_y) > tolerance then
    failures[#failures + 1] = string.format("origin %.17g", origin)
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
''')

    def test_numeric_inputs_bypass_ipe_tonumber_precision_loss(self):
        script = LUA_IPE_STUB + r'''
local lua_tonumber = tonumber
function tonumber(value, base)
  if type(value) == "number" then
    return lua_tonumber(string.format("%.14g", value), base)
  end
  return lua_tonumber(value, base)
end
''' + f"\ndofile({str(CIRCLES)!r})\n" + r'''
local GEOMETRY = assert(_G.CIRCLES)
local supplied = 1 + 2 ^ -20
local parsed = GEOMETRY.circle_from_table({
  center = { x = 1e12 + 3.75, y = -1e12 },
  radius = supplied,
}, "circle")
assert(parsed.radius == supplied, string.format("radius changed from %.17g to %.17g", supplied, parsed.radius))
assert(parsed.center.x == 1e12 + 3.75, string.format("coordinate changed to %.17g", parsed.center.x))
assert(GEOMETRY.finite_number_option(supplied, nil, "value") == supplied)

local centers = GEOMETRY.circle_homothety_centers(
  { center = { x = 1e12, y = -1e12 }, radius = 1 },
  { center = { x = 1e12 + 8, y = -1e12 + 6 }, radius = supplied }
)
local expected_x = 1e12 + 8 / (1 - supplied)
local expected_y = -1e12 + 6 / (1 - supplied)
assert(centers.external.x == expected_x, string.format("wrong external x: %.17g", centers.external.x))
assert(centers.external.y == expected_y, string.format("wrong external y: %.17g", centers.external.y))
'''
        completed = subprocess.run(
            ["lua5.4", "-e", script],
            check=False,
            text=True,
            capture_output=True,
        )

        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_center_radius_rejects_nonfinite_values(self):
        self.assert_lua_ok(r'''
for _, radius in ipairs({ math.huge, -math.huge, 0 / 0 }) do
  local model = new_test_model({}, "alpha")
  local result = GEOMETRY.create_circle_construction(model, {
    operation = "center_radius",
    center = { x = 0, y = 0 },
    radius = radius,
    marks = false,
    labels = false,
  })
  assert(not result.created, "nonfinite radius must not create an object")
  assert(result.error == "radius must be a finite number", tostring(result.error))
  assert(model.transaction == nil, "invalid radius must not register a transaction")
end
''')

    def test_active_attributes_and_arc_arrows_are_preserved(self):
        self.assert_lua_ok(r'''
local model = new_test_model({}, "alpha")
model.attributes = {
  stroke = "active-stroke",
  fill = "active-fill",
  pen = "active-pen",
  dashstyle = "active-dash",
  markshape = "mark/circle(sx)",
  symbolsize = "active-symbol-size",
  textsize = "active-text-size",
  forward = true,
  backward = true,
}
local result = GEOMETRY.create_circle_construction(model, {
  operation = "center_radius",
  center = { x = 2, y = 3 },
  radius = 5,
  marks = true,
  labels = true,
})
assert(result.created, result.error)
local path, mark, text = table.unpack(model.transaction.objects)
assert(path._attributes.stroke == "active-stroke")
assert(path._attributes.pen == "active-pen")
assert(mark._attributes.stroke == "active-stroke")
assert(mark._attributes.symbolsize == "active-symbol-size")
assert(mark:symbol() == "mark/circle(sx)")
assert(text._attributes.stroke == "active-stroke")
assert(text._attributes.textsize == "active-text-size")

local arc_model = new_test_model({}, "alpha")
arc_model.attributes = model.attributes
local arc = GEOMETRY.create_circle_construction(arc_model, {
  operation = "arc_three_points",
  points = {
    { x = 1, y = 0 },
    { x = 0, y = 1 },
    { x = -1, y = 0 },
  },
  marks = false,
  labels = false,
})
assert(arc.created, arc.error)
assert(arc_model.transaction.objects[1]._arrows == true,
  "open arcs must preserve active arrow attributes")
assert(arc_model.transaction.objects[1]._attributes.forward == true)
assert(arc_model.transaction.objects[1]._attributes.backward == true)
''')

    def test_extended_tangent_never_becomes_shorter_than_its_geometry(self):
        self.assert_lua_ok(r'''
local object = GEOMETRY.tangent_line_element({
  kind = "point",
  from = { x = 0, y = 0 },
  to = { x = 100, y = 0 },
  direction = { x = 1, y = 0 },
}, { extend = true }, {}, 20)
local segment = object:shape()[1][1]
local length = math.sqrt((segment[2].x - segment[1].x) ^ 2 + (segment[2].y - segment[1].y) ^ 2)
assert(length >= 100 - 1e-9, tostring(length))
assert(segment[1].x <= 0 and segment[2].x >= 100,
  "the extended path must still reach its original tangency endpoint")
''')

    def test_primary_mark_defines_center_and_arc_through_point(self):
        self.assert_lua_ok(r'''
local radius_point = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(10, 0))
local center_point = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(0, 0))
local circle_model = new_test_model({
  { object = radius_point, selected = true, layer = "alpha" },
  { object = center_point, selected = true, layer = "alpha" },
}, "alpha", 2)
local circle = GEOMETRY.create_circle_construction(circle_model, {
  operation = "center_point", marks = false, labels = false,
})
assert(circle.created, circle.error)
assert(circle.result.center.x == 0 and circle.result.center.y == 0)
assert(math.abs(circle.result.radius - 10) < 1e-9)

local start = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(1, 0))
local finish = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(-1, 0))
local through = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(0, 1))
local arc_model = new_test_model({
  { object = start, selected = true, layer = "alpha" },
  { object = finish, selected = true, layer = "alpha" },
  { object = through, selected = true, layer = "alpha" },
}, "alpha", 3)
local arc = GEOMETRY.create_circle_construction(arc_model, {
  operation = "arc_three_points", marks = false, labels = false,
})
assert(arc.created, arc.error)
assert(arc.result.orientation == "counterclockwise", arc.result.orientation)
''')

    def test_only_real_marks_and_exact_required_selection_are_accepted(self):
        self.assert_lua_ok(r'''
local fake_reference = ipe.Reference({}, "arrow/normal(spx)", ipe.Vector(0, 0))
local model = new_test_model({
  { object = fake_reference, selected = true, layer = "alpha" },
}, "alpha", 1)
local rejected = GEOMETRY.create_circle_construction(model, {
  operation = "center_radius", radius = 10, marks = false, labels = false,
})
assert(not rejected.created)
assert(model.transaction == nil)

local first = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(0, 0))
local second = ipe.Reference({}, "mark/disk(sx)", ipe.Vector(4, 0))
local unrelated = ipe.Path({}, {
  { type = "curve", closed = true,
    { type = "segment", ipe.Vector(0, 0), ipe.Vector(1, 0) },
    { type = "segment", ipe.Vector(1, 0), ipe.Vector(0, 0) } },
})
local extra_model = new_test_model({
  { object = first, selected = true, layer = "alpha" },
  { object = second, selected = true, layer = "alpha" },
  { object = unrelated, selected = true, layer = "alpha" },
}, "alpha", 1)
local extra = GEOMETRY.create_circle_construction(extra_model, {
  operation = "diameter", marks = false, labels = false,
})
assert(not extra.created)
assert(extra_model.transaction == nil)
''')

    def test_invisible_active_layer_uses_the_native_warning(self):
        self.assert_lua_ok(r'''
local model = new_test_model({}, "hidden", nil, false)
local result = GEOMETRY.create_circle_construction(model, {
  operation = "center_radius",
  center = { x = 0, y = 0 },
  radius = 10,
  marks = false,
  labels = false,
})
assert(result.created, result.error)
assert(#model.warnings == 1)
assert(model.warnings[1].title == "Active layer is invisible")
assert(model.warnings[1].detail:find("layer 'hidden'", 1, true))
assert(model.warnings[1].detail:find("don't be surprised", 1, true))
''')

    def test_labels_are_independent_from_tangency_marks(self):
        self.assert_lua_ok(r'''
local model = new_test_model({}, "alpha")
local result = GEOMETRY.create_tangent_lines(model, {
  operation = "point_circle",
  point = { x = 20, y = 0 },
  circle = { center = { x = 0, y = 0 }, radius = 10 },
  tangent_points = false,
  labels = true,
})
assert(result.created, result.error)
local paths, references, texts = 0, 0, 0
for _, object in ipairs(model.transaction.objects) do
  if object:type() == "path" then paths = paths + 1 end
  if object:type() == "reference" then references = references + 1 end
  if object:type() == "text" then texts = texts + 1 end
end
assert(paths == 2)
assert(references == 0)
assert(texts == 2, "labels must not depend on tangent point marks")
''')

    def test_tangent_mark_deduplication_scales_with_the_construction(self):
        self.assert_lua_ok(r'''
local tiny = GEOMETRY.tangent_line_mark_points({
  kind = "external", scale = 1e-9,
  from = { x = 0, y = 0 }, to = { x = 5e-16, y = 0 },
})
assert(#tiny == 1)
local large_near = GEOMETRY.tangent_line_mark_points({
  kind = "external", scale = 1e9,
  from = { x = 0, y = 0 }, to = { x = 500, y = 0 },
})
assert(#large_near == 1)
local large_distinct = GEOMETRY.tangent_line_mark_points({
  kind = "external", scale = 1e9,
  from = { x = 0, y = 0 }, to = { x = 2000, y = 0 },
})
assert(#large_distinct == 2)
''')

    def test_tangent_solver_handles_unit_geometry_near_trillion_coordinates(self):
        self.assert_lua_ok(r'''
local origin = 1e12
local solutions = GEOMETRY.tangent_circles_from_constraints({
  { type = "point", point = { x = origin, y = origin } },
  { type = "point", point = { x = origin + 1, y = origin } },
  { type = "point", point = { x = origin, y = origin + 1 } },
})
assert(#solutions == 1, tostring(#solutions))
local circle = solutions[1]
assert(math.abs(circle.center.x - (origin + 0.5)) <= 2e-4)
assert(math.abs(circle.center.y - (origin + 0.5)) <= 2e-4)
assert(math.abs(circle.radius - 1 / math.sqrt(2)) <= 2e-4)
''')

    def test_p1_p2_still_define_an_explicit_line_for_line_tangents(self):
        self.assert_lua_ok(r'''
local model = new_test_model({}, "alpha")
local result = GEOMETRY.create_tangent_lines(model, {
  circle = { center = { x = 0, y = 0 }, radius = 10 },
  p1 = { x = -20, y = 0 },
  p2 = { x = 20, y = 0 },
  mode = "parallel",
  tangent_points = false,
  labels = false,
})
assert(result.created, result.error)
assert(result.operation == "circle_line")
assert(result.tangent_count == 2)
''')

    def test_preview_is_generated_by_the_standalone_circles_api(self):
        self.assert_lua_ok(r'''
_G.GEOMETRY = nil
_G.GEOMETRY_DIALOGS = nil
local model = new_test_model({}, "alpha")
local preview = GEOMETRY.preview_shape_data(model, "circle_construct", {
  operation = "center_radius",
  center = { x = 2, y = 3 },
  radius = 5,
  marks = true,
  labels = true,
})
assert(preview.created == true)
assert(preview.shape_count >= 4)
assert(preview.captured_count == 3)
assert(model.transaction == nil, "preview must not mutate the real model")
''')


if __name__ == "__main__":
    unittest.main()
