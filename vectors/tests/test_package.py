import hashlib
import os
import posixpath
import re
import stat
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


VECTORS_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = VECTORS_ROOT.parent
PACKAGE_SCRIPT = REPOSITORY_ROOT / "scripts" / "package.sh"
VERSION = (VECTORS_ROOT / "VERSION").read_text(encoding="utf-8").strip()
ARCHIVE_ROOT = f"vectors-v{VERSION}"
LINK_PATTERN = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")


class VectorsPackageTest(unittest.TestCase):
    def build_package(self, destination: Path) -> tuple[Path, Path]:
        environment = os.environ.copy()
        environment["IPELETS_DIST_DIR"] = str(destination)
        subprocess.run(
            [str(PACKAGE_SCRIPT), "vectors"],
            cwd=REPOSITORY_ROOT,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        archive = destination / f"vectors-v{VERSION}.zip"
        return archive, destination / f"vectors-v{VERSION}.zip.sha256"

    def test_archive_is_self_contained_and_has_a_valid_checksum(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive, checksum = self.build_package(Path(temporary_directory))
            expected_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual(
                checksum.read_text(encoding="ascii"),
                f"{expected_digest}  {archive.name}\n",
            )
            with zipfile.ZipFile(archive) as package:
                names = set(package.namelist())
                for relative in (
                    "vectors.lua",
                    "README.md",
                    "README.pt-BR.md",
                    "CHANGELOG.md",
                    "VERSION",
                    "LICENSE",
                    "NOTICE.md",
                    "examples/README.md",
                    "examples/vectors-inclined-plane.ipe",
                    "examples/vectors-overview.ipe",
                    "docs/images/01_vectors_overview.png",
                    "docs/images/02_components_in_current_axes.png",
                    "docs/images/03_components_in_selected_directions.png",
                    "docs/images/04_connected_resultants.png",
                    "docs/images/05_ordered_subtraction.png",
                    "docs/images/06_weight_on_inclined_plane.png",
                ):
                    self.assertIn(f"{ARCHIVE_ROOT}/{relative}", names, relative)

                for readme in ("README.md", "README.pt-BR.md"):
                    readme_path = f"{ARCHIVE_ROOT}/{readme}"
                    content = package.read(readme_path).decode("utf-8")
                    self.assertNotIn("](../LICENSE)", content)
                    self.assertNotIn("](../NOTICE.md)", content)
                    for target in LINK_PATTERN.findall(content):
                        target = target.strip().strip("<>")
                        if target.startswith("#") or re.match(r"^[a-z]+://", target):
                            continue
                        target = target.split("#", 1)[0]
                        resolved = posixpath.normpath(
                            posixpath.join(posixpath.dirname(readme_path), target)
                        )
                        self.assertIn(resolved, names, f"{readme}: {target}")

    def test_archive_is_byte_reproducible_and_excludes_development_files(self) -> None:
        with tempfile.TemporaryDirectory() as first_directory, tempfile.TemporaryDirectory() as second_directory:
            first, _ = self.build_package(Path(first_directory))
            second, _ = self.build_package(Path(second_directory))
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as package:
                for name in package.namelist():
                    self.assertNotIn("/tests/", name)
                    self.assertNotIn("__pycache__", name)
                    self.assertFalse(name.endswith((".py", ".pyc", ".so", ".o")), name)
                    info = package.getinfo(name)
                    mode = (info.external_attr >> 16) & 0o777
                    self.assertEqual(
                        mode,
                        stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH,
                    )
                    self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))
                    if name.endswith((".lua", ".md", ".ipe", ".txt")):
                        content = package.read(name).decode("utf-8", errors="strict")
                        for forbidden in (
                            "/home/", ".codex", "IPE_MCP_BRIDGE_STATE",
                            "IPE_GEOMETRY_API", "mailbox", "__pycache__",
                        ):
                            self.assertNotIn(forbidden, content, f"{name}: {forbidden}")


if __name__ == "__main__":
    unittest.main()
