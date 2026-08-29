import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "circles.lua"


class CirclesReleaseContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_release_metadata_is_present(self) -> None:
        self.assertIn("-- Circles 1.0.0", self.source)
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
            "docs/images/circles-overview.svg",
            "docs/images/circles-overview.png",
            "docs/images/tangent-circles-live-preview.png",
            "docs/images/tangent-circle-result.png",
        ):
            with self.subTest(relative=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                self.assertGreater(path.stat().st_size, 0, relative)


if __name__ == "__main__":
    unittest.main()
