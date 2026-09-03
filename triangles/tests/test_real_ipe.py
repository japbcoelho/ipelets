import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRIANGLES = ROOT / "triangles.lua"


REAL_IPE_AUDIT = r'''
local source, output = assert(argv[1]), assert(argv[2])
dofile(source)
local api = assert(TRIANGLES)
assert(#methods == 2)
assert(#api.center_definitions == 24)
assert(#api.derived_definitions == 9)

local document = ipe.Document()
if #document == 0 then document:append(ipe.Page()) end
local model = {
  doc = document,
  pno = 1,
  vno = 1,
  attributes = {
    stroke = "black", pen = "normal", dashstyle = "normal",
    markshape = "mark/disk(sx)", symbolsize = "normal", textsize = "normal",
  },
  warnings = {},
}
function model:page() return self.doc[self.pno] end
function model:warning(title, detail)
  self.warnings[#self.warnings + 1] = { title = title, detail = detail }
end
function model:register(transaction)
  transaction.redo(transaction, self.doc)
end

local function vector(point) return ipe.Vector(point.x, point.y) end
local function triangle_path(points)
  local a, b, c = vector(points[1]), vector(points[2]), vector(points[3])
  return ipe.Path({ stroke = "black", pen = "normal" }, {
    { type = "curve", closed = true;
      { type = "segment"; a, b },
      { type = "segment"; b, c },
      { type = "segment"; c, a },
    },
  }, false)
end

local points = {
  { x = 90, y = 80 }, { x = 500, y = 105 }, { x = 190, y = 610 },
}
model:page():insert(nil, triangle_path(points), 1, "alpha")
local selected = api.create_triangle_centers(model, {
  center = "excenter_a", marks = true, labels = false, group_output = false,
})
assert(selected.created == true, selected.error)
assert(selected.element_count == 1)
assert(selected.result.source_kind == "path")
assert(selected.result.vertex_order == "upper_ccw")

local centers = api.create_triangle_centers(model, {
  points = points, centers = "all_centers", marks = true, labels = true,
  defining_lines = true, circle = true,
})
assert(centers.created == true, centers.error)
assert(centers.center_count == 24)

local derived = api.create_triangle_derived(model, {
  points = points, operation = "all", point = { x = 245, y = 230 },
  polygon = true, marks = true, labels = true, circle = true,
  contact_circle = "incircle",
})
assert(derived.created == true, derived.error)
assert(derived.derived_count == 9)

for _, entry in ipairs({ model:page()[#model:page() - 1], model:page()[#model:page()] }) do
  local metadata = api.parse_metadata(entry)
  assert(metadata.status == "current")
end

assert(document:save(output, "xml", { nozip = true }))
local reopened, error_message = ipe.Document(output)
assert(reopened, error_message)
assert(#reopened == 1, "reopened page count: " .. tostring(#reopened))
assert(#reopened[1] == #document[1],
  "reopened object count: " .. tostring(#reopened[1]) .. " / " .. tostring(#document[1]))
print("TRIANGLES_REAL_IPE_OK centers=24 derived=9 objects=" .. tostring(#reopened[1]))
'''


class TrianglesRealIpeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.flatpak = shutil.which("flatpak")
        if cls.flatpak is None:
            raise unittest.SkipTest("Flatpak is not available")
        installed = subprocess.run(
            [cls.flatpak, "info", "org.otfried.Ipe"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if installed.returncode != 0:
            raise unittest.SkipTest("Ipe Flatpak is not installed")

    def test_all_features_with_real_ipelib_and_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory(prefix="triangles-real-ipe-") as temporary:
            temporary_path = Path(temporary)
            script = temporary_path / "triangles_real_audit.lua"
            output = temporary_path / "triangles-real-audit.ipe"
            script.write_text(textwrap.dedent(REAL_IPE_AUDIT), encoding="utf-8")
            completed = subprocess.run(
                [
                    self.flatpak,
                    "run",
                    "--filesystem=/tmp",
                    f"--env=IPESCRIPTS={temporary_path}",
                    "--command=ipescript",
                    "org.otfried.Ipe",
                    "triangles_real_audit",
                    str(TRIANGLES),
                    str(output),
                ],
                check=False,
                text=True,
                capture_output=True,
                timeout=30,
            )
            combined = completed.stdout + completed.stderr
            self.assertEqual(completed.returncode, 0, combined)
            self.assertIn("TRIANGLES_REAL_IPE_OK centers=24 derived=9", combined)
            self.assertTrue(output.is_file(), combined)
            self.assertGreater(output.stat().st_size, 0)


if __name__ == "__main__":
    unittest.main()
