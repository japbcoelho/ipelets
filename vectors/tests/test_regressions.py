import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IPELET = ROOT / "vectors.lua"


LUA_HARNESS = r'''
ipe = {}
ipeui = {}
shortcuts = {}

function ipe.Vector(x, y)
  return { x = x, y = y }
end

FAIL_CUSTOM = false

function ipe.Path(attributes, shape, with_arrows)
  return {
    kind = "path",
    attributes = attributes,
    shape_value = shape,
    with_arrows = with_arrows,
    type = function() return "path" end,
    shape = function(self) return self.shape_value end,
    matrix = function() return nil end,
    get = function(self, name) return self.attributes[name] end,
    setCustom = function(self, value)
      if FAIL_CUSTOM then error("metadata write failed") end
      self.custom = value
    end,
  }
end

function ipe.Text(attributes, text, position)
  return {
    kind = "text",
    attributes = attributes,
    text_value = text,
    position_value = position,
    type = function() return "text" end,
    set = function(self, name, value) self.attributes[name] = value end,
    setCustom = function(self, value)
      if FAIL_CUSTOM then error("metadata write failed") end
      self.custom = value
    end,
  }
end

local VALID_STYLES = {
  pen = { normal = true, thick = true },
  symbol = { ["arrow/normal(spx)"] = true },
  arrowsize = { normal = true, large = true },
  color = { black = true, red = true },
  dashstyle = { normal = true, solid = true, dashed = true, dotted = true },
  opacity = { normal = true, opaque = true },
  textsize = { normal = true, large = true },
  labelstyle = { math = true },
}

local SHEETS = {
  has = function(_, kind, value)
    return VALID_STYLES[kind] ~= nil and VALID_STYLES[kind][value] == true
  end,
}

function make_shape(a, b)
  return {
    {
      type = "curve",
      closed = false,
      { type = "segment", a, b },
    },
  }
end

function make_path(a, b, attributes)
  local attrs = attributes or { farrow = true, stroke = "black", pen = "normal" }
  return ipe.Path(attrs, make_shape(a, b), true)
end

function make_model(objects, selection, primary)
  local selected = selection or {}
  local page = objects or {}
  function page:primarySelection() return primary or selected[1] end
  function page:selection() return selected end
  function page:active() return "alpha" end

  local created = {}
  local registered = {}
  local warnings = {}
  local model = {
    pno = 1,
    vno = 1,
    attributes = { stroke = "black", textsize = "normal", labelstyle = "math" },
    snap = {},
    doc = { sheets = function() return SHEETS end },
    page = function() return page end,
    selection = function() return selected end,
    creation = function(_, label, object)
      created[#created + 1] = { label = label, object = object }
    end,
    register = function(_, transaction)
      registered[#registered + 1] = transaction
      for _, object in ipairs(transaction.objects or {}) do
        created[#created + 1] = { label = transaction.label, object = object }
      end
    end,
    warning = function(_, title, message)
      warnings[#warnings + 1] = { title = title, message = message }
    end,
  }
  return model, page, created, registered, warnings
end

function expect_error(callback, fragment)
  local ok, message = pcall(callback)
  assert(not ok, "expected an error containing: " .. fragment)
  assert(tostring(message):find(fragment, 1, true), tostring(message))
  return tostring(message)
end
'''


class VectorsRegressionTest(unittest.TestCase):
    def run_lua(self, body: str, *, timeout: float = 10.0) -> subprocess.CompletedProcess[str]:
        source = LUA_HARNESS + "\ndofile(" + json.dumps(str(IPELET)) + ")\n" + body
        return subprocess.run(
            ["lua5.4", "-e", source],
            check=False,
            text=True,
            capture_output=True,
            timeout=timeout,
        )

    def assert_lua_ok(self, body: str, *, timeout: float = 10.0) -> None:
        completed = self.run_lua(body, timeout=timeout)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_only_one_open_straight_segment_is_a_vector(self):
        self.assert_lua_ok(r'''
local valid_attrs = { farrow = true, stroke = "black", pen = "normal" }

local mixed = ipe.Path(valid_attrs, {
  { type = "curve", closed = false,
    { type = "segment", ipe.Vector(0, 0), ipe.Vector(10, 0) },
    { type = "spline", ipe.Vector(10, 0), ipe.Vector(12, 2) } },
}, true)
local model = make_model({ mixed }, { 1 }, 1)
expect_error(function() VECTORS.selected_vector_segment(model) end,
  "Selected path must be one open straight segment")

local closed = ipe.Path(valid_attrs, {
  { type = "curve", closed = true,
    { type = "segment", ipe.Vector(0, 0), ipe.Vector(10, 0) } },
}, true)
model = make_model({ closed }, { 1 }, 1)
expect_error(function() VECTORS.selected_vector_segment(model) end,
  "Selected path must be one open straight segment")

local multiple = ipe.Path(valid_attrs, {
  { type = "curve", closed = false,
    { type = "segment", ipe.Vector(0, 0), ipe.Vector(10, 0) } },
  { type = "ellipse", {} },
}, true)
model = make_model({ multiple }, { 1 }, 1)
expect_error(function() VECTORS.selected_vector_segment(model) end,
  "Selected path must be one open straight segment")
''')

    def test_zero_length_and_ambiguous_double_arrow_are_rejected(self):
        self.assert_lua_ok(r'''
local zero = make_path(ipe.Vector(2, 2), ipe.Vector(2, 2))
local model = make_model({ zero }, { 1 }, 1)
expect_error(function() VECTORS.selected_vector_segment(model) end,
  "Selected vector must have positive length")

local double = make_path(ipe.Vector(0, 0), ipe.Vector(10, 0), {
  farrow = true, rarrow = true, stroke = "black", pen = "normal",
})
model = make_model({ double }, { 1 }, 1)
expect_error(function() VECTORS.selected_vector_segment(model) end,
  "Selected vector must have exactly one arrowhead direction")
''')

    def test_touch_tolerance_does_not_change_vector_arithmetic(self):
        self.assert_lua_ok(r'''
local first = make_path(ipe.Vector(0, 0), ipe.Vector(10, 0))
local second = make_path(ipe.Vector(10.0005, 0), ipe.Vector(20.0005, 0))
local model = make_model({ first, second }, { 1, 2 }, 1)
local result = VECTORS.create_selected_vector_resultant_auto(model, { touch_tolerance = 0.001 })
assert(math.abs(result.vector.x - 20) < 1e-12, result.vector.x)
assert(math.abs(result.finish.x - result.start.x - 20) < 1e-12)

local third = make_path(ipe.Vector(20.001, 0), ipe.Vector(30.001, 0))
model = make_model({ first, second, third }, { 1, 2, 3 }, 1)
result = VECTORS.create_selected_vector_resultant_auto(model, { touch_tolerance = 0.001 })
assert(result.mode == "directed_polyline")
assert(math.abs(result.vector.x - 30) < 1e-12, result.vector.x)
assert(math.abs(result.finish.x - result.start.x - 30) < 1e-12)

first = make_path(ipe.Vector(0, 0), ipe.Vector(10, 0))
second = make_path(ipe.Vector(0.0005, 0), ipe.Vector(5.0005, 0))
model = make_model({ first, second }, { 1, 2 }, 1)
result = VECTORS.create_selected_vector_subtraction_auto(model, { touch_tolerance = 0.001 })
assert(math.abs(result.vector.x - 5) < 1e-12, result.vector.x)
assert(math.abs(result.finish.x - result.start.x - 5) < 1e-12)
''')

    def test_scaled_norm_handles_large_finite_directions(self):
        self.assert_lua_ok(r'''
local result = VECTORS.components_in_directions(
  ipe.Vector(3, 4),
  ipe.Vector(1e308, 0),
  ipe.Vector(0, 1e308)
)
assert(result.first_scalar == 3)
assert(result.second_scalar == 4)
assert(result.first.x == 3 and result.first.y == 0)
assert(result.second.x == 0 and result.second.y == 4)
''')

    def test_labels_metadata_and_arrowfix_attributes_preserve_meaning(self):
        self.assert_lua_ok(r'''
local labels = VECTORS.component_labels("$F$", "12")
assert(labels.first == "F_1" and labels.second == "F_2")

local source = make_path(ipe.Vector(0, 0), ipe.Vector(30, 40))
local model, _, created = make_model({ source }, { 1 }, 1)
local result = VECTORS.create_selected_vector_components(model, {
  label_base = "A;role=forged=1\\%",
})
assert(result.created_count == #created)
for _, entry in ipairs(created) do
  assert(entry.object.custom:find("label_base=A%3Brole%3Dforged%3D1\\%25", 1, true))
end

local arrowfix = {
  kind = "group",
  type = function() return "group" end,
  matrix = function() return nil end,
  get = function() return "undefined" end,
  getCustom = function()
    return "arrowfix:line;x1=0;y1=0;x2=10;y2=0;farrow=true;" ..
      "stroke=0.1 0.2 0.3;pen=2.5;farrowshape=arrow/normal(spx);farrowsize=1.25"
  end,
}
local second = make_path(ipe.Vector(10, 0), ipe.Vector(15, 0))
model, _, created = make_model({ arrowfix, second }, { 1, 2 }, 1)
VECTORS.create_selected_vector_resultant_auto(model, {})
local attrs = created[1].object.attributes
assert(type(attrs.pen) == "number" and attrs.pen == 2.5)
assert(type(attrs.farrowsize) == "number" and attrs.farrowsize == 1.25)
assert(type(attrs.stroke) == "table")
assert(attrs.stroke.r == 0.1 and attrs.stroke.g == 0.2 and attrs.stroke.b == 0.3)
''')

    def test_nested_attributes_and_numeric_options_are_strict(self):
        self.assert_lua_ok(r'''
local source = make_path(ipe.Vector(0, 0), ipe.Vector(30, 40))
local model = make_model({ source }, { 1 }, 1)

expect_error(function()
  VECTORS.create_selected_vector_components(model, {
    component_attributes = { farrowshape = "definitely_missing_arrow" },
  })
end, "component_attributes.farrowshape")

expect_error(function()
  VECTORS.create_selected_vector_components(model, {
    component_attributes = { made_up = true },
  })
end, "Unsupported component_attributes attribute: made_up")

expect_error(function()
  VECTORS.create_selected_vector_components(model, {
    component_attributes = { pathmode = "filled" },
  })
end, "component_attributes.pathmode must be 'stroked'")

expect_error(function()
  VECTORS.create_selected_vector_components(model, { label_offset = -1 })
end, "label_offset must be non-negative")

expect_error(function()
  VECTORS.create_selected_vector_components(model, {
    component_attributes = { stroke = { r = 1, g = 0 } },
  })
end, "component_attributes.stroke")

local second = make_path(ipe.Vector(30, 40), ipe.Vector(40, 40))
model = make_model({ source, second }, { 1, 2 }, 1)
expect_error(function()
  VECTORS.create_selected_vector_resultant_auto(model, { touch_tolerance = "0.001" })
end, "touch_tolerance must be a finite number")
''')

    def test_metadata_failures_and_missing_transactions_are_not_silent(self):
        self.assert_lua_ok(r'''
local first = make_path(ipe.Vector(0, 0), ipe.Vector(10, 0))
local second = make_path(ipe.Vector(10, 0), ipe.Vector(20, 0))
local model, _, created = make_model({ first, second }, { 1, 2 }, 1)
FAIL_CUSTOM = true
expect_error(function()
  VECTORS.create_selected_vector_resultant_auto(model, {})
end, "metadata write failed")
assert(#created == 0)
FAIL_CUSTOM = false

local source = make_path(ipe.Vector(0, 0), ipe.Vector(30, 40))
model, _, created = make_model({ source }, { 1 }, 1)
model.register = nil
expect_error(function()
  VECTORS.create_selected_vector_components(model, {})
end, "model:register is required for atomic vector creation")
assert(#created == 0)
''')

    def test_menu_warnings_hide_lua_locations_and_preview_tool_is_local(self):
        self.assert_lua_ok(r'''
assert(_G.VECTOR_PREVIEW_TOOL == nil)
local model, _, _, _, warnings = make_model({}, {}, nil)
local result = methods[1].run(model)
assert(result == false)
assert(#warnings == 1)
assert(not warnings[1].message:match("vectors%.lua:%d+"), warnings[1].message)
assert(warnings[1].message:find("Select exactly 1 arrowed segment", 1, true))
''')

    def test_large_reverse_primary_chain_is_near_linear(self):
        self.assert_lua_ok(r'''
local count = 400
local objects = {}
local selected = {}
for index = 1, count do
  objects[index] = make_path(ipe.Vector(index - 1, 0), ipe.Vector(index, 0))
  selected[index] = index
end
local model = make_model(objects, selected, count)
local started = os.clock()
local result = VECTORS.create_selected_vector_resultant_auto(model, {})
local elapsed = os.clock() - started
assert(result.source_count == count)
assert(result.vector.x == count)
assert(elapsed < 1.0, "connected-chain analysis took " .. tostring(elapsed) .. " seconds")
''', timeout=4.0)


if __name__ == "__main__":
    unittest.main()
