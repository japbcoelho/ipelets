import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CIRCLES = ROOT / "circles.lua"


class CirclesExtensionsContractTest(unittest.TestCase):
    def run_lua(self, body: str) -> subprocess.CompletedProcess[str]:
        script = r'''
ipe = {
  Vector = function(x, y) return { x = x, y = y } end,
}
function ipe.Matrix(...) return { values = { ... } } end
local function object(kind, attributes, data)
  local value = { kind = kind, attributes = attributes, data = data, custom = "" }
  function value:type() return self.kind end
  function value:matrix() return ipe.Matrix() end
  function value:shape() return self.data end
  function value:position() return self.data end
  function value:symbol() return self.symbol_name end
  function value:getCustom() return self.custom end
  function value:setCustom(custom) self.custom = custom end
  return value
end
function ipe.Path(attributes, shape) return object("path", attributes, shape) end
function ipe.Reference(attributes, name, position)
  local value = object("reference", attributes, position)
  value.symbol_name = name
  return value
end
function ipe.Text(attributes, text, position) return object("text", attributes, position) end
function ipe.Arc(_, alpha, beta) return { start = alpha, finish = beta } end
ipeui = {}
dofile(%r)
local api = assert(_G.CIRCLES)

local function new_model()
  local objects = {}
  local page = setmetatable({}, { __len = function() return #objects end })
  function page:active() return "alpha" end
  function page:objects()
    local index = 0
    return function()
      index = index + 1
      local entry = objects[index]
      if entry then return index, entry.object, entry.selected, entry.layer end
    end
  end
  function page:primarySelection() return self._primary end
  function page:visible() return true end
  function page:deselectAll() end
  function page:insert(_, value, selected, layer)
    objects[#objects + 1] = { object = value, selected = selected, layer = layer }
  end

  local doc = { [1] = page }
  local model = { pno = 1, vno = 1, objects = objects, page_object = page }
  function model:page() return page end
  function model:register(registration)
    self.registration = registration
    registration:redo(doc)
  end
  function model:warning(title, detail)
    self.last_warning = { title = title, detail = detail }
  end
  return model
end
%s
''' % (str(CIRCLES), body)
        return subprocess.run(
            ["lua5.4", "-e", script],
            check=False,
            text=True,
            capture_output=True,
        )

    def assert_lua_passes(self, body: str) -> None:
        completed = self.run_lua(body)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_circles_through_two_points_radius_returns_zero_one_or_two_solutions(self):
        self.assert_lua_passes(r'''
local function close(actual, expected)
  return math.abs(actual - expected) < 1e-9
end

local two = api.circles_through_two_points_radius(
  { x = -3, y = 0 }, { x = 3, y = 0 }, 5
)
assert(#two == 2)
assert(close(two[1].radius, 5) and close(two[2].radius, 5))
assert(close(two[1].center.x, 0) and close(two[2].center.x, 0))
assert(close(math.abs(two[1].center.y), 4))
assert(close(math.abs(two[2].center.y), 4))
assert(two[1].center.y * two[2].center.y < 0)

local one = api.circles_through_two_points_radius(
  { x = -5, y = 0 }, { x = 5, y = 0 }, 5
)
assert(#one == 1)
assert(close(one[1].center.x, 0) and close(one[1].center.y, 0))
assert(close(one[1].radius, 5))

local none = api.circles_through_two_points_radius(
  { x = -6, y = 0 }, { x = 6, y = 0 }, 5
)
assert(#none == 0)

local distinct = pcall(api.circles_through_two_points_radius,
  { x = 1, y = 1 }, { x = 1, y = 1 }, 5)
assert(distinct == false)
local positive = pcall(api.circles_through_two_points_radius,
  { x = 0, y = 0 }, { x = 1, y = 0 }, 0)
assert(positive == false)
''')

    def test_circle_power_polar_covers_signed_power_and_polar_line(self):
        self.assert_lua_passes(r'''
local circle = { center = { x = 2, y = -1 }, radius = 5 }
local point = { x = 12, y = -1 }
local result = api.circle_power_polar(circle, point)
local line = result.polar
local radial_x = point.x - circle.center.x
local radial_y = point.y - circle.center.y
local foot_x = line.point.x - circle.center.x
local foot_y = line.point.y - circle.center.y

assert(math.abs(result.power - 75) < 1e-9)
assert(math.abs(foot_x * radial_x + foot_y * radial_y - 25) < 1e-9)
assert(math.abs(line.direction.x * radial_x + line.direction.y * radial_y) < 1e-9)
assert(math.abs(line.point.x - 4.5) < 1e-9)

local inside = api.circle_power_polar(circle, { x = 2, y = -1 })
assert(math.abs(inside.power + 25) < 1e-9)
assert(inside.polar == nil)
local boundary = api.circle_power_polar(circle, { x = 7, y = -1 })
assert(math.abs(boundary.power) < 1e-9)
''')

    def test_circle_pole_of_line_is_the_dual_of_the_polar_operation(self):
        self.assert_lua_passes(r'''
local circle = { center = { x = 2, y = -1 }, radius = 5 }
local line = { p1 = { x = 12, y = -20 }, p2 = { x = 12, y = 20 } }
local pole = api.circle_pole_of_line(circle, line)
assert(math.abs(pole.point.x - 4.5) < 1e-9)
assert(math.abs(pole.point.y + 1) < 1e-9)
assert(math.abs(pole.foot.x - 12) < 1e-9)
assert(math.abs(pole.foot.y + 1) < 1e-9)

local long_line_pole = api.circle_pole_of_line(
  { center = { x = 0, y = 0 }, radius = 1 },
  { p1 = { x = -1e12, y = 1 }, p2 = { x = 1e12, y = 1 } }
)
assert(math.abs(long_line_pole.point.x) < 1e-9)
assert(math.abs(long_line_pole.point.y - 1) < 1e-9)

local dual = api.circle_power_polar(circle, pole.point).polar
assert(math.abs(dual.point.x - 12) < 1e-9)
assert(math.abs(dual.direction.x) < 1e-9)
assert(math.abs(math.abs(dual.direction.y) - 1) < 1e-9)

local valid, message = pcall(api.circle_pole_of_line, circle, {
  p1 = { x = 2, y = -20 }, p2 = { x = 2, y = 20 },
})
assert(valid == false)
assert(tostring(message):find("line through the circle center", 1, true))
''')

    def test_pole_creator_and_optional_construction_guides_create_expected_objects(self):
        self.assert_lua_passes(r'''
local pole_model = new_model()
local pole = api.create_circle_construction(pole_model, {
  operation = "pole_of_line",
  circle = { center = { x = 2, y = -1 }, radius = 5 },
  line = { p1 = { x = 12, y = -20 }, p2 = { x = 12, y = 20 } },
  marks = true,
  labels = false,
  auxiliaries = true,
})
assert(pole.created == true)
assert(pole.operation == "pole_of_line")
assert(math.abs(pole.result.point.x - 4.5) < 1e-9)
assert(pole.element_count == 2)
assert(pole_model.objects[1].object.kind == "reference")
assert(pole_model.objects[2].object.kind == "path")

local plain_model = new_model()
local plain = api.create_circle_construction(plain_model, {
  operation = "through_three_points",
  points = { { x = -4, y = 0 }, { x = 4, y = 0 }, { x = 0, y = 3 } },
  marks = false,
  labels = false,
  auxiliaries = false,
})
local guided_model = new_model()
local guided = api.create_circle_construction(guided_model, {
  operation = "through_three_points",
  points = { { x = -4, y = 0 }, { x = 4, y = 0 }, { x = 0, y = 3 } },
  marks = false,
  labels = false,
  auxiliaries = true,
  line_length = 40,
})
assert(plain.created and guided.created)
assert(plain.element_count == 1)
assert(guided.element_count == 3)
''')

    def test_tangent_guides_candidate_counts_and_keyboard_navigation(self):
        self.assert_lua_passes(r'''
local constraints = {
  operation = "three_lines",
  lines = {
    { p1 = { x = 0, y = 0 }, p2 = { x = 10, y = 0 } },
    { p1 = { x = 0, y = 0 }, p2 = { x = 0, y = 10 } },
    { p1 = { x = 10, y = 0 }, p2 = { x = 0, y = 10 } },
  },
  line_side = "both",
  max_solutions = 2,
  center_marks = false,
  tangent_points = false,
  auxiliaries = true,
}

local candidate_model = new_model()
local operation, candidates, _, info = api.tangent_circle_candidates(candidate_model, constraints)
assert(operation == "three_lines")
assert(#candidates == 2)
assert(info.total_count == 4)
assert(info.shown_count == 2)
assert(info.truncated == true)

candidate_model.ui = {
  shapeTool = function(_, tool)
    candidate_model.tool = tool
    tool.setColor = function() end
    tool.setShape = function(shapes) candidate_model.preview_shapes = shapes end
  end,
  zoom = function() return 1 end,
  update = function() end,
  explain = function(_, text) candidate_model.explanation = text end,
  finishTool = function() candidate_model.finished = true end,
  pos = function() return { x = 0, y = 0 } end,
}
local interactive = api.choose_tangent_circle_interactively(candidate_model, constraints)
assert(interactive.interactive == true)
assert(interactive.candidate_count == 2)
assert(interactive.total_candidate_count == 4)
assert(interactive.truncated == true)
assert(candidate_model.tool.current_index == 1)
assert(candidate_model.tool:key("k") == true)
assert(candidate_model.tool.current_index == 2)
assert(candidate_model.tool:key("j") == true)
assert(candidate_model.tool.current_index == 1)
assert(candidate_model.explanation:find("showing 2 of 4", 1, true))
assert(candidate_model.tool:key("a") == true)
assert(candidate_model.finished == true)
assert(#candidate_model.objects == 8)

local default_model = new_model()
local default_result = api.create_tangent_circles(default_model, {
  operation = "three_lines",
  lines = constraints.lines,
  line_side = "both",
  max_solutions = 1,
  tangent_points = false,
  auxiliaries = false,
})
assert(default_result.created == true)
assert(default_result.circle_count == 1)
assert(default_result.element_count == 2)
assert(default_model.objects[1].object.kind == "path")
assert(default_model.objects[2].object.kind == "reference")

local truncated_model = new_model()
truncated_model.ui = {
  explain = function(_, message) truncated_model.explanation = message end,
}
local truncated_result = api.create_tangent_circles(truncated_model, {
  operation = "point_line_circle",
  point = { x = 70, y = 70 },
  line = { p1 = { x = -20, y = -20 }, p2 = { x = 90, y = -20 } },
  circle = { center = { x = 0, y = 30 }, radius = 10 },
  circle_mode = "external",
  line_side = "both",
  max_solutions = 1,
  center_marks = false,
  tangent_points = false,
})
assert(truncated_result.created == true)
assert(truncated_result.circle_count == 1)
assert(truncated_result.total_circle_count == 2)
assert(truncated_result.truncated == true)
assert(truncated_result.notice:find("Created 1 of 2", 1, true))
assert(truncated_model.explanation == truncated_result.notice)

local line_model = new_model()
local guided_lines = api.create_tangent_lines(line_model, {
  operation = "point_circle",
  point = { x = 10, y = 0 },
  circle = { center = { x = 0, y = 0 }, radius = 4 },
  tangent_points = false,
  labels = false,
  auxiliaries = true,
})
assert(guided_lines.created == true)
assert(guided_lines.tangent_count == 2)
assert(guided_lines.element_count == 4)
''')

    def test_circle_homothety_centers_handles_distinct_and_equal_radii(self):
        self.assert_lua_passes(r'''
local function close(actual, expected)
  return math.abs(actual - expected) < 1e-9
end

local centers = api.circle_homothety_centers(
  { center = { x = 0, y = 0 }, radius = 2 },
  { center = { x = 12, y = 0 }, radius = 4 }
)
assert(close(centers.internal.x, 4) and close(centers.internal.y, 0))
assert(close(centers.external.x, -12) and close(centers.external.y, 0))

local equal = api.circle_homothety_centers(
  { center = { x = 0, y = 2 }, radius = 3 },
  { center = { x = 10, y = 4 }, radius = 3 }
)
assert(close(equal.internal.x, 5) and close(equal.internal.y, 3))
assert(equal.external == nil)

local valid = pcall(api.circle_homothety_centers,
  { center = { x = 0, y = 0 }, radius = 0 },
  { center = { x = 1, y = 0 }, radius = 1 })
assert(valid == false)
''')

    def test_homothety_center_output_never_invents_a_concentric_axis(self):
        self.assert_lua_passes(r'''
local function close(actual, expected)
  return math.abs(actual - expected) < 1e-9
end

local function assert_axis(model, ax, ay, bx, by)
  assert(#model.objects == 1, "marks=false should create one auxiliary path")
  local object = model.objects[1].object
  assert(object.kind == "path", "marks=false must not create reference markers")
  local curve = object.data and object.data[1]
  local segment = curve and curve[1]
  assert(curve and curve.type == "curve" and segment and segment.type == "segment",
    "homothety output should be one center-axis segment")
  local p1, p2 = segment[1], segment[2]
  local forward = close(p1.x, ax) and close(p1.y, ay) and close(p2.x, bx) and close(p2.y, by)
  local reverse = close(p1.x, bx) and close(p1.y, by) and close(p2.x, ax) and close(p2.y, ay)
  assert(forward or reverse, "center-axis segment has the wrong endpoints")
end

local distinct_model = new_model()
local distinct = api.create_circle_construction(distinct_model, {
  operation = "homothety_centers",
  circles = {
    { center = { x = 0, y = 0 }, radius = 2 },
    { center = { x = 12, y = 0 }, radius = 4 },
  },
  marks = false,
  labels = false,
})
assert(distinct.created == true)
assert(distinct.element_count == 1, "marks=false should replace homothety markers with one axis")
assert_axis(distinct_model, 4, 0, -12, 0)

local equal_model = new_model()
local equal = api.create_circle_construction(equal_model, {
  operation = "homothety_centers",
  circles = {
    { center = { x = 0, y = 2 }, radius = 3 },
    { center = { x = 10, y = 4 }, radius = 3 },
  },
  marks = false,
  labels = false,
})
assert(equal.created == true)
assert(equal.result.external == nil)
assert(equal.element_count == 1, "equal-radius homothety should keep one visible center axis")
assert_axis(equal_model, 0, 2, 10, 4)

local hidden_model = new_model()
local hidden = api.create_circle_construction(hidden_model, {
  operation = "homothety_centers",
  circles = {
    { center = { x = 5, y = 7 }, radius = 2 },
    { center = { x = 5, y = 7 }, radius = 4 },
  },
  marks = false,
  labels = false,
  line_length = 40,
})
assert(hidden.created == false)
assert(hidden.error == "The homothety centers coincide; enable center marks or labels to show the result.")
assert(#hidden_model.objects == 0, "a concentric result must not invent an arbitrary axis")

local labeled_model = new_model()
local labeled = api.create_circle_construction(labeled_model, {
  operation = "homothety_centers",
  circles = {
    { center = { x = 5, y = 7 }, radius = 2 },
    { center = { x = 5, y = 7 }, radius = 4 },
  },
  marks = false,
  labels = true,
})
assert(labeled.created == true)
assert(labeled.element_count == 1)
assert(labeled_model.objects[1].object.kind == "text")
''')

    def test_circle_construction_exposes_the_three_new_operations(self):
        self.assert_lua_passes(r'''
local circles_model = new_model()
local circles = api.create_circle_construction(circles_model, {
  operation = "two_points_radius",
  points = { { x = -3, y = 0 }, { x = 3, y = 0 } },
  radius = 5,
  marks = false,
})
assert(circles.created == true)
assert(circles.operation == "two_points_radius")
assert(circles.result.type == "circles")
assert(#circles.result.circles == 2)
assert(circles.element_count == 2 and #circles_model.objects == 2)

local polar_model = new_model()
local polar = api.create_circle_construction(polar_model, {
  operation = "power_polar",
  circle = { center = { x = 2, y = -1 }, radius = 5 },
  point = { x = 12, y = -1 },
  line_length = 40,
  marks = false,
})
assert(polar.created == true)
assert(polar.operation == "power_polar")
assert(math.abs(polar.result.power - 75) < 1e-9)
assert(polar.result.polar ~= nil)
assert(polar.element_count == 1 and #polar_model.objects == 1)

local homothety_model = new_model()
local homothety = api.create_circle_construction(homothety_model, {
  operation = "homothety_centers",
  circles = {
    { center = { x = 0, y = 0 }, radius = 2 },
    { center = { x = 12, y = 0 }, radius = 4 },
  },
  marks = true,
  labels = false,
})
assert(homothety.created == true)
assert(homothety.operation == "homothety_centers")
assert(math.abs(homothety.result.internal.x - 4) < 1e-9)
assert(math.abs(homothety.result.external.x + 12) < 1e-9)
assert(homothety.element_count == 2 and #homothety_model.objects == 2)
''')

    def test_standalone_menu_exposes_circle_construction_and_center_tool(self):
        self.assert_lua_passes(r'''
assert(#methods == 5)
assert(methods[1].label == "Construct: circle")
assert(methods[2].label == "Construct: tangent circle")
assert(methods[3].label == "Construct: tangent lines")
assert(methods[4].label == "Inversion/radicals: operations")
assert(methods[5].label == "Mark center: circle/ellipse/arc")
assert(methods[1].run == CIRCLES_DIALOGS.circle_construct)
assert(methods[2].run == CIRCLES_DIALOGS.tangent_circles)
assert(methods[3].run == CIRCLES_DIALOGS.tangent_lines)
assert(methods[4].run == CIRCLES_DIALOGS.inversion_radical)
''')

    def test_circle_construction_dialog_uses_local_preview_lifecycle(self):
        source = CIRCLES.read_text(encoding="utf-8")
        self.assertIn("local function circle_construct_dialog", source)
        start = source.index("local function circle_construct_dialog")
        end = source.index("local INVERSION_DIALOG_OPERATIONS", start)
        dialog = source[start:end]
        for marker in [
            'ipeui.Dialog(model.ui:win(), "Circle construction")',
            'operation = CIRCLE_DIALOG_OPERATIONS[dialog:get("operation")].operation',
            'P.start_dialog_preview(model, dialog, "circle_construct", read_options)',
            'dialog:addButton("preview", "&Preview"',
            'dialog:addButton("ok", "&Create", "accept")',
            'local result = R.create_circle_construction(model, options)',
            'remember_dialog_state(state, options, dialog',
            'update_circle_dialog(dialog)',
            'label = "Required selection"',
        ]:
            self.assertIn(marker, dialog)
        self.assertIn("circle_construct = circle_construct_dialog", source)


if __name__ == "__main__":
    unittest.main()
