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


CONICS_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = CONICS_ROOT.parent
PACKAGE_SCRIPT = REPOSITORY_ROOT / "scripts" / "package.sh"
VERSION = (CONICS_ROOT / "VERSION").read_text(encoding="utf-8").strip()
ARCHIVE_ROOT = f"conics-v{VERSION}"
LINK_PATTERN = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")


class ConicsPackageTest(unittest.TestCase):
    def build_package(self, destination: Path) -> tuple[Path, Path]:
        environment = os.environ.copy()
        environment["IPELETS_DIST_DIR"] = str(destination)
        subprocess.run(
            [str(PACKAGE_SCRIPT), "conics"],
            cwd=REPOSITORY_ROOT,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        archive = destination / f"conics-v{VERSION}.zip"
        checksum = destination / f"conics-v{VERSION}.zip.sha256"
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
                for relative in (
                    "conics.lua",
                    "README.md",
                    "README.pt-BR.md",
                    "CHANGELOG.md",
                    "VERSION",
                    "LICENSE",
                    "NOTICE.md",
                    "examples/README.md",
                    "examples/conics-overview.ipe",
                    "examples/conics-feature-gallery.ipe",
                    "docs/images/conics-overview.svg",
                    "docs/images/conics-overview.png",
                    "docs/images/conics-advanced-workflows.png",
                    "docs/images/conics-five-point-live-preview.png",
                    "docs/images/conics-property-guides.png",
                    "docs/images/conics-parabolas.png",
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

    def test_archive_is_byte_reproducible(self) -> None:
        with tempfile.TemporaryDirectory() as first_directory, tempfile.TemporaryDirectory() as second_directory:
            first, _ = self.build_package(Path(first_directory))
            second, _ = self.build_package(Path(second_directory))
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_archive_excludes_development_private_and_executable_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive, _ = self.build_package(Path(temporary_directory))
            with zipfile.ZipFile(archive) as package:
                names = package.namelist()
                for name in names:
                    self.assertNotIn("/tests/", name)
                    self.assertNotIn("__pycache__", name)
                    self.assertFalse(name.endswith((".py", ".pyc", ".so", ".o")), name)
                    info = package.getinfo(name)
                    mode = (info.external_attr >> 16) & 0o777
                    self.assertEqual(mode, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
                    self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))

                for name in names:
                    if not name.endswith((".lua", ".md", ".ipe", ".svg", ".txt")):
                        continue
                    content = package.read(name).decode("utf-8", errors="strict")
                    for forbidden in (
                        "/home/",
                        ".codex",
                        "IPE_MCP_BRIDGE_STATE",
                        "IPE_GEOMETRY_API",
                        "mailbox",
                        "__pycache__",
                    ):
                        self.assertNotIn(forbidden, content, f"{name}: {forbidden}")


if __name__ == "__main__":
    unittest.main()
