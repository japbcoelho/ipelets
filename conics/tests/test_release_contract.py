import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "conics.lua"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()


class ConicsReleaseContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_release_metadata_is_present_and_synchronized(self) -> None:
        self.assertEqual(VERSION, "1.1.0")
        self.assertIn("-- Conics", self.source)
        self.assertIn("Copyright (C) 2026 japbcoelho", self.source)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", self.source)
        self.assertIn(f"Conics {VERSION}", self.source)
        self.assertIn('label = "Conics"', self.source)
        self.assertIn("goodies.lua", self.source)

    def test_runtime_source_is_standalone_and_has_no_local_infrastructure(self) -> None:
        self.assertIsNone(re.search(r"\b(?:dofile|loadfile|require)\s*\(", self.source))
        for forbidden in (
            "_G.GEOMETRY",
            "_G.GEOMETRY_DIALOGS",
            "IPE_MCP",
            ".codex",
            "/home/",
            "mailbox",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.source)

    def test_public_menu_contains_exactly_seven_tools(self) -> None:
        menu = self.source[self.source.index("methods = {") :]
        expected = [
            "Construct: conic",
            "Construct: ellipse",
            "Construct: hyperbola",
            "Construct: parabola",
            "Features: conic",
            "Inspect: conic",
            "Metadata: revalidate selected conic",
        ]
        labels = re.findall(r'\{ label = "([^"]+)", run = ', menu)
        self.assertEqual(labels, expected)

    def test_documentation_assets_exist(self) -> None:
        for relative in (
            "examples/conics-overview.ipe",
            "examples/conics-feature-gallery.ipe",
        ):
            with self.subTest(relative=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                self.assertGreater(path.stat().st_size, 0, relative)


if __name__ == "__main__":
    unittest.main()
