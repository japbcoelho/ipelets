import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "circles.lua"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()


class CirclesReleaseContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_release_metadata_is_present(self) -> None:
        self.assertEqual(VERSION, "1.0.1")
        self.assertIn(f"-- Circles {VERSION}", self.source)
        self.assertIn(f"Circles {VERSION}", self.source)
        self.assertIn("Copyright (C) 2026 japbcoelho", self.source)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", self.source)
        self.assertIn('label = "Circles"', self.source)

    def test_runtime_source_has_no_external_loader_dependency(self) -> None:
        self.assertIsNone(re.search(r"\b(?:dofile|loadfile|require)\s*\(", self.source))
        self.assertNotIn("_G.GEOMETRY", self.source)
        self.assertNotIn("_G.GEOMETRY_DIALOGS", self.source)

    def test_public_menu_contains_exactly_five_tools(self) -> None:
        menu = self.source[self.source.index("methods = {") :]
        expected = [
            "Construct: circle",
            "Construct: tangent circle",
            "Construct: tangent lines",
            "Inversion/radicals: operations",
            "Mark center: circle/ellipse/arc",
        ]
        labels = re.findall(r'\{ label = "([^"]+)", run = ', menu)
        self.assertEqual(labels, expected)

    def test_documentation_assets_exist(self) -> None:
        for relative in (
            "examples/circles-overview.ipe",
            "docs/images/01_all_tangent_circle_candidates.png",
            "docs/images/02_inversion_and_radicals.png",
            "docs/images/03_tangent_lines.png",
            "docs/images/04_tangent_circle_constraints.png",
            "docs/images/05_mark_ellipse_center.png",
        ):
            with self.subTest(relative=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                self.assertGreater(path.stat().st_size, 0, relative)

    def test_release_links_are_namespaced_and_current(self) -> None:
        release = f"releases/tag/circles-v{VERSION}"
        for relative in ("README.md", "README.pt-BR.md"):
            self.assertIn(release, (ROOT / relative).read_text(encoding="utf-8"))
        repository_readme = (ROOT.parent / "README.md").read_text(encoding="utf-8")
        self.assertIn(f"[Circles {VERSION}]", repository_readme)
        self.assertIn(release, repository_readme)


if __name__ == "__main__":
    unittest.main()
