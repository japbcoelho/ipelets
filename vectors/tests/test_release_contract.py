import re
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vectors.lua"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()


class VectorsReleaseContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_release_metadata_and_api_are_synchronized(self) -> None:
        self.assertEqual(VERSION, "1.0.0")
        self.assertIn(f"-- Vectors {VERSION}", self.source)
        self.assertIn("Copyright (C) 2026 japbcoelho", self.source)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", self.source)
        self.assertIn(f"Vectors {VERSION}", self.source)
        self.assertIn('API.API_VERSION = 1', self.source)
        self.assertIn(f'API.VERSION = "{VERSION}"', self.source)
        self.assertIn('label = "Vectors"', self.source)

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

    def test_public_menu_contains_exactly_four_intentional_tools(self) -> None:
        menu = self.source[self.source.index("methods = {") :]
        labels = re.findall(r'label\s*=\s*"([^"]+)"', menu)
        self.assertEqual(
            labels,
            [
                "Create components in current axes",
                "Decompose into selected directions",
                "Create resultant from selected (auto)",
                "Subtract selected (auto)",
            ],
        )
        self.assertNotIn("Vector:", menu)

    def test_numeric_topology_metadata_and_namespace_contracts_are_present(self) -> None:
        self.assertIn("scaled_hypot", self.source)
        self.assertIn("endpoint_graph", self.source)
        self.assertIn("metadata_escape", self.source)
        self.assertIn("has_significant_length", self.source)
        self.assertIn("local VECTOR_PREVIEW_TOOL = {}", self.source)
        self.assertNotIn("\nVECTOR_PREVIEW_TOOL = {}", self.source)
        self.assertNotIn("collect_segments", self.source)

    def test_documentation_assets_exist(self) -> None:
        examples = (
            "examples/vectors-inclined-plane.ipe",
            "examples/vectors-overview.ipe",
        )
        images = (
            "docs/images/01_vectors_overview.png",
            "docs/images/02_components_in_current_axes.png",
            "docs/images/03_components_in_selected_directions.png",
            "docs/images/04_connected_resultants.png",
            "docs/images/05_ordered_subtraction.png",
            "docs/images/06_weight_on_inclined_plane.png",
        )
        for relative in examples + images:
            with self.subTest(relative=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                self.assertGreater(path.stat().st_size, 0, relative)

        for relative in images:
            path = ROOT / relative
            data = path.read_bytes()[:24]
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n", relative)
            width, height = struct.unpack(">II", data[16:24])
            self.assertEqual(width, 1800, relative)
            self.assertGreaterEqual(height, 1000, relative)

        self.assertFalse((ROOT / "docs/images/vectors-overview.svg").exists())
        self.assertFalse((ROOT / "docs/images/vectors-overview.png").exists())

        for relative in examples:
            example_source = (ROOT / relative).read_text(encoding="utf-8")
            self.assertEqual(example_source.count("<preamble>"), 1, relative)
            for inherited_setting in (
                "Meu Preâmbulo Padrão",
                r"\usepackage{pgfplots}",
                r"\usepackage{physics}",
                r"\usepackage{siunitx}",
            ):
                with self.subTest(relative=relative, inherited_setting=inherited_setting):
                    self.assertNotIn(inherited_setting, example_source)

        inclined_source = (ROOT / examples[0]).read_text(encoding="utf-8")
        self.assertIn('fill="gray"', inclined_source)
        self.assertIn('fill="lightgray"', inclined_source)
        self.assertIn('name="mark/disk(sx)"', inclined_source)
        self.assertIn("role=component_1", inclined_source)
        self.assertIn("role=component_2", inclined_source)

    def test_root_documentation_and_issue_forms_include_vectors(self) -> None:
        repository = ROOT.parent
        self.assertIn("[Vectors](vectors/)", (repository / "README.md").read_text(encoding="utf-8"))
        self.assertIn(
            "[Vectors](vectors/README.pt-BR.md)",
            (repository / "README.pt-BR.md").read_text(encoding="utf-8"),
        )
        for relative in (
            ".github/ISSUE_TEMPLATE/bug_report.yml",
            ".github/ISSUE_TEMPLATE/feature_request.yml",
        ):
            self.assertIn("- Vectors", (repository / relative).read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
