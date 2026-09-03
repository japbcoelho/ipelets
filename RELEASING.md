# Releasing an ipelet

This repository publishes each ipelet independently. A release must describe one directory, use a namespaced tag, and contain artifacts built from the exact tagged commit.

## Release contract

- Use the tag format `<ipelet>-v<version>`, for example `vectors-v1.0.0`.
- Keep the directory `VERSION`, runtime version, README links, tests, changelog, root version table, and release table synchronized.
- Treat an already published tag and its assets as immutable. Publish a patch version when packaging or documentation must change.
- Build documentation PNGs from an editable `.ipe` source with Ipe. Do not use synthetic or independently redrawn SVG previews as substitutes for actual Ipe output.
- Keep tests, generators, caches, local configuration, and private development paths out of the release archive.

## Verification

From a clean checkout of the intended commit, run:

```bash
./scripts/validate.sh
./scripts/package.sh <ipelet>
sha256sum -c dist/<ipelet>-v<version>.zip.sha256
unzip -t dist/<ipelet>-v<version>.zip
```

Inspect the archive inventory, verify every relative README link, confirm the runtime version, and review every included image. The ZIP and checksum must be the two release assets.

## Publication

Create an annotated tag only after validation succeeds, push that exact tag, and create the GitHub release from it. Release notes must state the tested Ipe and Lua versions, the checks actually run, package contents, compatibility notes, and the archive checksum.

After upload, download both assets again, run the checksum verification on the downloaded files, confirm the release is neither a draft nor a prerelease, and verify the GitHub release points to the intended tag and commit. Mark the most recently published ipelet as the latest release.
