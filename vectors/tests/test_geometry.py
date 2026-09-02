import json
import subprocess
import unittest
from pathlib import Path

from test_regressions import LUA_HARNESS


ROOT = Path(__file__).resolve().parents[1]
IPELET = ROOT / "vectors.lua"


class VectorsGeometryTest(unittest.TestCase):
    def run_lua(self, body: str) -> None:
        source = LUA_HARNESS + "\ndofile(" + json.dumps(str(IPELET)) + ")\n" + body
        completed = subprocess.run(
            ["lua5.4", "-e", source],
            check=False,
            text=True,
            capture_output=True,
            timeout=10,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)

    def test_cartesian_and_oblique_components_reconstruct_the_vector(self):
        self.run_lua(r'''
local angle = math.pi / 6
local axes = {
  f1 = ipe.Vector(math.cos(angle), math.sin(angle)),
  f2 = ipe.Vector(-math.sin(angle), math.cos(angle)),
}
local cartesian = VECTORS.components_in_axes(ipe.Vector(30, 40), axes)
assert(math.abs(cartesian.first.x + cartesian.second.x - 30) < 1e-12)
assert(math.abs(cartesian.first.y + cartesian.second.y - 40) < 1e-12)

local oblique = VECTORS.components_in_directions(
  ipe.Vector(30, 40),
  ipe.Vector(1, 0),
  ipe.Vector(1, 1)
)
assert(math.abs(oblique.first_scalar + 10) < 1e-12)
assert(math.abs(oblique.second_scalar - 40 * math.sqrt(2)) < 1e-12)
assert(math.abs(oblique.first.x + oblique.second.x - 30) < 1e-12)
assert(math.abs(oblique.first.y + oblique.second.y - 40) < 1e-12)
''')

    def test_all_four_public_creators_generate_expected_editable_objects(self):
        self.run_lua(r'''
local source = make_path(ipe.Vector(0, 0), ipe.Vector(30, 40))
local model, _, created, registered = make_model({ source }, { 1 }, 1)
local components = VECTORS.create_selected_vector_components(model, {
  label_base = "F", label_style = "xy",
})
assert(components.created and components.created_count == 6)
assert(#created == 6 and #registered == 1)

local d1 = make_path(ipe.Vector(0, 0), ipe.Vector(10, 0), {
  stroke = "black", pen = "normal",
})
local d2 = make_path(ipe.Vector(0, 0), ipe.Vector(10, 10), {
  stroke = "black", pen = "normal",
})
model, _, created, registered = make_model({ source, d1, d2 }, { 1, 2, 3 }, 1)
local oblique = VECTORS.create_selected_vector_components_in_directions(model, {})
assert(oblique.created and oblique.created_count == 6)
assert(oblique.source_index == 1 and oblique.first_direction_index == 2)
assert(#created == 6 and #registered == 1)

local first = make_path(ipe.Vector(0, 0), ipe.Vector(30, 0))
local second = make_path(ipe.Vector(0, 0), ipe.Vector(0, 40))
model, _, created = make_model({ first, second }, { 1, 2 }, 1)
local resultant = VECTORS.create_selected_vector_resultant_auto(model, {})
assert(resultant.mode == "parallelogram" and resultant.contact == "tail_tail")
assert(resultant.vector.x == 30 and resultant.vector.y == 40 and #created == 1)

model, _, created = make_model({ first, second }, { 1, 2 }, 1)
local difference = VECTORS.create_selected_vector_subtraction_auto(model, {})
assert(difference.mode == "common_tail" and difference.contact == "tail_tail")
assert(difference.vector.x == 30 and difference.vector.y == -40 and #created == 1)
''')

    def test_chain_modes_primary_order_and_disconnected_rejection(self):
        self.run_lua(r'''
local first = make_path(ipe.Vector(0, 0), ipe.Vector(30, 0))
local second = make_path(ipe.Vector(30, 0), ipe.Vector(30, 40))
local third = make_path(ipe.Vector(30, 40), ipe.Vector(10, 40))
local model = make_model({ first, second, third }, { 1, 2, 3 }, 1)
local result = VECTORS.create_selected_vector_resultant_auto(model, {})
assert(result.mode == "directed_polyline")
assert(result.vector.x == 10 and result.vector.y == 40)

model = make_model({ first, second, third }, { 1, 2, 3 }, 2)
local difference = VECTORS.create_selected_vector_subtraction_auto(model, {})
assert(difference.mode == "chain_difference")
assert(difference.minuend_source_index == 2)
assert(difference.vector.x == -10 and difference.vector.y == 40)

local isolated = make_path(ipe.Vector(100, 0), ipe.Vector(120, 0))
model = make_model({ first, second, isolated }, { 1, 2, 3 }, 1)
expect_error(function()
  VECTORS.create_selected_vector_resultant_auto(model, {})
end, "connected endpoint graph")
''')

    def test_oblique_source_inference_and_pair_contact_rules(self):
        self.run_lua(r'''
local source = make_path(ipe.Vector(0, 0), ipe.Vector(195, 160))
local direction_1 = make_path(ipe.Vector(0, 0), ipe.Vector(280, 0))
local direction_2 = make_path(ipe.Vector(0, 0), ipe.Vector(105, 255))
local model = make_model(
  { source, direction_1, direction_2 },
  { 1, 2, 3 },
  2
)
local components = VECTORS.create_selected_vector_components_in_directions(model, {})
assert(components.source_index == 1)
assert(components.first_direction_index == 2)
assert(components.second_direction_index == 3)
assert(components.first_scalar > 0 and components.second_scalar > 0)

local first = make_path(ipe.Vector(0, 0), ipe.Vector(10, 10))
local second = make_path(ipe.Vector(20, 0), ipe.Vector(10, 10))
model = make_model({ first, second }, { 1, 2 }, 1)
expect_error(function()
  VECTORS.create_selected_vector_resultant_auto(model, {})
end, "head-to-head contact is not a valid resultant layout")

model = make_model({ first, second }, { 1, 2 }, 1)
local difference = VECTORS.create_selected_vector_subtraction_auto(model, {})
assert(difference.mode == "common_head" and difference.contact == "head_head")
assert(difference.vector.x == 20 and difference.vector.y == 0)
''')

    def test_preview_uses_the_same_creators_without_mutating_the_model(self):
        self.run_lua(r'''
local source = make_path(ipe.Vector(0, 0), ipe.Vector(30, 40))
local model, _, created = make_model({ source }, { 1 }, 1)
local preview = VECTORS.preview_shape_data(model, "current_axes", {
  label_base = "F", label_style = "xy",
})
assert(preview.action == "current_axes")
assert(preview.shape_count == 4)
assert(preview.captured_object_count == 6)
assert(#created == 0)
''')


if __name__ == "__main__":
    unittest.main()
