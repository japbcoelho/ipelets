import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "conics.lua"
RUNTIME = ROOT / "tests/conics_runtime.lua"


class ConicsNumericalRegressionTest(unittest.TestCase):
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

    def test_quadratic_roots_keep_widely_separated_intersections(self) -> None:
        self.assert_lua_passes(r'''
local roots = api.conic_line_intersections(
  { 1, 0, 0, -1e16, 0, 1 },
  { p1 = { x = 0, y = 0 }, p2 = { x = 1, y = 0 } }
)
assert(#roots == 2)
assert(roots[1].x > 0 and approximate(roots[1].x, 1e-16, 1e-6))
assert(approximate(roots[2].x, 1e16, 1e-12))
''')

    def test_open_conic_paths_are_compact_continuous_and_finite(self) -> None:
        self.assert_lua_passes(r'''
local model = new_model()
local result = api.create_hyperbola(model, {
  operation = "parameters", center = { x = 0, y = 0 }, a = 30, b = 12,
  branch = "right", asymptotes = false, tolerance = 0.05,
})
assert(result.created == true, result.error)
local curve = model.entries[1].object:shape()[1]
assert(#curve > 0 and #curve < 512)
for index, spline in ipairs(curve) do
  assert(#spline == 4)
  for _, point in ipairs(spline) do
    assert(api.finite_number(point.x) and api.finite_number(point.y))
  end
  if index > 1 then
    assert(approximate(curve[index - 1][4].x, spline[1].x))
    assert(approximate(curve[index - 1][4].y, spline[1].y))
  end
end
''')

    def test_five_point_fit_rejects_nearly_collapsed_data(self) -> None:
        self.assert_lua_passes(r'''
local ok, message = pcall(api.conic_coefficients_from_five_points, {
  { x = 0, y = 0 }, { x = 1, y = 1e-14 }, { x = 2, y = 2e-14 },
  { x = 3, y = 3e-14 }, { x = 4, y = 4.000000000001e-14 },
})
assert(ok == false)
assert(tostring(message):find("stable", 1, true)
  or tostring(message):find("degenerate", 1, true)
  or tostring(message):find("ill-conditioned", 1, true))
''')


if __name__ == "__main__":
    unittest.main()
