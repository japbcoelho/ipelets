import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "triangles.lua"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
GALLERY_IMAGES = (
    "01_fundamental_centers_euler_line.png",
    "02_defining_lines.png",
    "03_contact_and_cevian_geometry.png",
    "04_nine_point_circle.png",
    "05_reference_point_constructions.png",
    "06_isogonal_isotomic_conjugates.png",
    "07_selected_named_centers.png",
)


class TrianglesReleaseContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_release_metadata_is_present_and_synchronized(self) -> None:
        self.assertEqual(VERSION, "1.0.0")
        self.assertIn(f"-- Triangles {VERSION}", self.source)
        self.assertIn("Copyright (C) 2026 japbcoelho", self.source)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", self.source)
        self.assertIn(f"Triangles {VERSION}", self.source)
        self.assertIn('label = "Triangles"', self.source)

    def test_runtime_is_one_standalone_file_without_local_infrastructure(self) -> None:
        self.assertIsNone(re.search(r"\b(?:dofile|loadfile|require)\s*\(", self.source))
        for forbidden in (
            "_G.GEOMETRY",
            "_G.GEOMETRY_DIALOGS",
            "IPE_MCP_BRIDGE_STATE",
            "IPE_GEOMETRY_API",
            ".codex",
            "/home/",
            "mailbox",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.source)

    def test_public_menu_contains_exactly_two_construction_tools(self) -> None:
        menu = self.source[self.source.index("methods = {") :]
        labels = re.findall(r'\{ label = "([^"]+)", run = ', menu)
        self.assertEqual(
            labels,
            [
                "Construct: triangle centers",
                "Construct: derived triangle geometry",
            ],
        )

    def test_center_dialog_uses_mathematical_sets_and_specific_outputs(self) -> None:
        for expected in (
            "Fundamental centers",
            "Contact / Cevian centers",
            "Euler-line centers",
            "Isogonal / Napoleon centers",
            "First isogonic center (X13)",
            "Second isogonic center (X14)",
            'label = "Defining lines"',
            'label = "Nine-point circle"',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.source)

        center_dialog = self.source[
            self.source.index("local function centers_dialog") :
            self.source.index("local POINT_SOURCE_CENTERS")
        ]
        for removed in (
            "Classic centers",
            "Advanced centers",
            "All centers",
            "Associated circle",
            "Contact marks",
        ):
            with self.subTest(removed=removed):
                self.assertNotIn(removed, center_dialog)

    def test_numeric_and_metadata_contracts_are_present(self) -> None:
        self.assertIn("MACHINE_EPSILON", self.source)
        self.assertIn("triangle_context", self.source)
        self.assertIn("barycentric_status", self.source)
        self.assertIn('"ideal"', self.source)
        self.assertIn('"ill_conditioned"', self.source)
        self.assertIn('"triangles:v1"', self.source)
        self.assertIn('string.format("%.17g,%.17g"', self.source)
        self.assertNotIn("local EPS = 1e-9", self.source)

    def test_documentation_assets_exist(self) -> None:
        for relative in ("examples/triangles-feature-gallery.ipe",) + tuple(
            f"docs/images/{name}" for name in GALLERY_IMAGES
        ):
            with self.subTest(relative=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                self.assertGreater(path.stat().st_size, 0, relative)

        image_names = {path.name for path in (ROOT / "docs/images").iterdir() if path.is_file()}
        self.assertEqual(image_names, set(GALLERY_IMAGES))
        gallery = (ROOT / "examples/triangles-feature-gallery.ipe").read_text(encoding="utf-8")
        self.assertEqual(gallery.count("<page>"), 7)
        pages = re.findall(r"<page>(.*?)</page>", gallery, flags=re.DOTALL)
        self.assertEqual(
            [page.count('pen="semithick"') for page in pages],
            [1, 3, 3, 1, 2, 1, 3],
        )

    def test_root_documentation_and_issue_forms_include_triangles(self) -> None:
        repository = ROOT.parent
        readme = (repository / "README.md").read_text(encoding="utf-8")
        readme_pt = (repository / "README.pt-BR.md").read_text(encoding="utf-8")
        self.assertIn(
            "### [Triangles](triangles/)\n\n"
            "[![Triangles: construct centers and derived triangle geometry]",
            readme,
        )
        self.assertIn(
            "### [Triangles](triangles/README.pt-BR.md)\n\n"
            "[![Triangles: construa centros e geometria derivada de triângulos]",
            readme_pt,
        )
        for relative in (
            ".github/ISSUE_TEMPLATE/bug_report.yml",
            ".github/ISSUE_TEMPLATE/feature_request.yml",
        ):
            self.assertIn("- Triangles", (repository / relative).read_text(encoding="utf-8"))

    def test_release_links_are_namespaced_and_current(self) -> None:
        release = f"releases/tag/triangles-v{VERSION}"
        for relative in ("README.md", "README.pt-BR.md"):
            self.assertIn(release, (ROOT / relative).read_text(encoding="utf-8"))
        repository_readme = (ROOT.parent / "README.md").read_text(encoding="utf-8")
        self.assertIn(f"[Triangles {VERSION}]", repository_readme)
        self.assertIn(release, repository_readme)


if __name__ == "__main__":
    unittest.main()
