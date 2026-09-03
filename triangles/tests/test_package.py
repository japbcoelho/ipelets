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


TRIANGLES_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = TRIANGLES_ROOT.parent
PACKAGE_SCRIPT = REPOSITORY_ROOT / "scripts" / "package.sh"
VERSION = (TRIANGLES_ROOT / "VERSION").read_text(encoding="utf-8").strip()
ARCHIVE_ROOT = f"triangles-v{VERSION}"
LINK_PATTERN = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
GALLERY_IMAGES = (
    "01_fundamental_centers_euler_line.png",
    "02_defining_lines.png",
    "03_contact_and_cevian_geometry.png",
    "04_nine_point_circle.png",
    "05_reference_point_constructions.png",
    "06_isogonal_isotomic_conjugates.png",
    "07_selected_named_centers.png",
)


class TrianglesPackageTest(unittest.TestCase):
    def build_package(self, destination: Path) -> tuple[Path, Path]:
        environment = os.environ.copy()
        environment["IPELETS_DIST_DIR"] = str(destination)
        subprocess.run(
            [str(PACKAGE_SCRIPT), "triangles"],
            cwd=REPOSITORY_ROOT,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        archive = destination / f"triangles-v{VERSION}.zip"
        checksum = destination / f"triangles-v{VERSION}.zip.sha256"
        return archive, checksum

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
                required = (
                    "triangles.lua",
                    "README.md",
                    "README.pt-BR.md",
                    "CHANGELOG.md",
                    "VERSION",
                    "LICENSE",
                    "NOTICE.md",
                    "examples/README.md",
                    "examples/triangles-feature-gallery.ipe",
                ) + tuple(f"docs/images/{name}" for name in GALLERY_IMAGES)
                for relative in required:
                    self.assertIn(f"{ARCHIVE_ROOT}/{relative}", names, relative)

                self.assertFalse(any(name.endswith(".svg") for name in names))

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

    def test_archive_is_byte_reproducible(self) -> None:
        with tempfile.TemporaryDirectory() as first_directory, tempfile.TemporaryDirectory() as second_directory:
            first, _ = self.build_package(Path(first_directory))
            second, _ = self.build_package(Path(second_directory))
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_archive_excludes_tests_private_paths_and_executable_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive, _ = self.build_package(Path(temporary_directory))
            with zipfile.ZipFile(archive) as package:
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
                    if name.endswith((".lua", ".md", ".ipe", ".svg", ".txt")):
                        content = package.read(name).decode("utf-8", errors="strict")
                        for forbidden in (
                            "/home/", ".codex", "IPE_MCP_BRIDGE_STATE",
                            "IPE_GEOMETRY_API", "mailbox", "__pycache__",
                        ):
                            self.assertNotIn(forbidden, content, f"{name}: {forbidden}")


if __name__ == "__main__":
    unittest.main()
