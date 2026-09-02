import hashlib
import os
import posixpath
import re
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


CIRCLES_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = CIRCLES_ROOT.parent
PACKAGE_SCRIPT = REPOSITORY_ROOT / "scripts" / "package.sh"
VERSION = (CIRCLES_ROOT / "VERSION").read_text(encoding="utf-8").strip()
ARCHIVE_ROOT = f"circles-v{VERSION}"
LINK_PATTERN = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")


class CirclesPackageTest(unittest.TestCase):
    def build_package(self, destination: Path) -> tuple[Path, Path]:
        environment = os.environ.copy()
        environment["IPELETS_DIST_DIR"] = str(destination)
        subprocess.run(
            [str(PACKAGE_SCRIPT), "circles"],
            cwd=REPOSITORY_ROOT,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        archive = destination / f"circles-v{VERSION}.zip"
        checksum = destination / f"circles-v{VERSION}.zip.sha256"
        return archive, checksum

    def test_archive_is_self_contained_and_has_a_valid_checksum(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive, checksum = self.build_package(Path(temporary_directory))
            self.assertTrue(archive.is_file())
            self.assertTrue(checksum.is_file())

            expected_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual(
                checksum.read_text(encoding="ascii"),
                f"{expected_digest}  {archive.name}\n",
            )

            with zipfile.ZipFile(archive) as package:
                names = set(package.namelist())
                for relative in (
                    "circles.lua",
                    "README.md",
                    "README.pt-BR.md",
                    "CHANGELOG.md",
                    "VERSION",
                    "LICENSE",
                    "NOTICE.md",
                    "examples/README.md",
                    "examples/circles-overview.ipe",
                    "docs/images/01_all_tangent_circle_candidates.png",
                    "docs/images/02_inversion_and_radicals.png",
                    "docs/images/03_tangent_lines.png",
                    "docs/images/04_tangent_circle_constraints.png",
                    "docs/images/05_mark_ellipse_center.png",
                ):
                    self.assertIn(f"{ARCHIVE_ROOT}/{relative}", names, relative)

                for readme in ("README.md", "README.pt-BR.md"):
                    readme_path = f"{ARCHIVE_ROOT}/{readme}"
                    content = package.read(readme_path).decode("utf-8")
                    self.assertNotIn("](../LICENSE)", content)
                    for target in LINK_PATTERN.findall(content):
                        target = target.strip().strip("<>")
                        if target.startswith("#") or re.match(r"^[a-z]+://", target):
                            continue
                        target = target.split("#", 1)[0]
                        resolved = posixpath.normpath(
                            posixpath.join(posixpath.dirname(readme_path), target)
                        )
                        self.assertIn(resolved, names, f"{readme}: {target}")

    def test_archive_excludes_development_and_retired_examples(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive, _ = self.build_package(Path(temporary_directory))
            with zipfile.ZipFile(archive) as package:
                names = package.namelist()

            forbidden_fragments = (
                "/tests/",
                "__pycache__",
                "circle-through-three-points",
                "radical-center",
                "tangent-lines",
            )
            for fragment in forbidden_fragments:
                self.assertFalse(
                    any(fragment in name for name in names),
                    fragment,
                )


if __name__ == "__main__":
    unittest.main()
