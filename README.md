# Ipelets collection

[Leia em português](README.pt-BR.md)

A curated collection of independent extensions for the [Ipe drawing editor](https://ipe.otfried.org/). Each ipelet lives in its own directory with installation instructions, examples, tests, and release notes.

[![Circles: preview every tangent-circle candidate and click to create one](circles/docs/images/01_all_tangent_circle_candidates.png)](circles/)

[**Conics: construct, classify, inspect, and annotate editable conics**](conics/)

[![Triangles: construct centers and derived triangle geometry](triangles/docs/images/01_fundamental_centers_euler_line.png)](triangles/)

[![Vectors: decompose vectors and construct exact vector arithmetic](vectors/docs/images/01_vectors_overview.png)](vectors/)

## Available ipelets

| Ipelet | Version | Description |
| --- | --- | --- |
| [Circles](circles/) | 1.0.0 | Circle construction, tangencies, inversion, radical geometry, center marking, and live previews. |
| [Conics](conics/) | 1.1.0 | Exact and fitted conics, dual and mixed constructions, intersections, arcs, analytic features, inspection, and metadata repair. |
| [Triangles](triangles/) | 1.0.0 | Twenty-four triangle centers, nine derived constructions, explicit reference points, live previews, and versioned metadata. |
| [Vectors](vectors/) | 1.0.0 | Axis and oblique decomposition, connected resultants, ordered subtraction, strict topology, and atomic editable output. |

## Quick installation

On Linux, install an ipelet with the repository helper:

```bash
./scripts/install.sh circles
```

Replace `circles` with `conics`, `triangles`, or `vectors` to install another ipelet.

The helper detects the Ipe Flatpak installation and otherwise uses the standard `~/.ipe/ipelets` directory. Restart Ipe after installation.

Manual installation and platform-specific details are documented inside each ipelet directory.
Prebuilt archives for each ipelet are available on the [GitHub releases page](https://github.com/japbcoelho/ipelets/releases).

## Repository layout

```text
.
├── circles/          Circles source, documentation, examples, and tests
├── conics/           Conics source, documentation, examples, and tests
├── triangles/        Triangles source, documentation, examples, and tests
├── vectors/          Vectors source, documentation, examples, and tests
├── scripts/          Installation, validation, and packaging helpers
├── .github/          Continuous integration and contribution templates
└── LICENSE           Repository license
```

The installed runtime contains only the corresponding `.lua` file. Release archives also include the documentation, editable examples, license, and publication images; tests and development helpers remain outside the installed ipelet.

## Validation

Run every local check with:

```bash
./scripts/validate.sh
```

The same checks run in GitHub Actions. They validate Lua syntax, execute the independent geometry regression suite, and verify the public runtime contract.

## Releases

Create a release archive with:

```bash
./scripts/package.sh circles
```

The generated archive and its SHA-256 checksum are written to `dist/` and are intentionally not tracked by Git. The archive is self-contained: every relative link in its README files resolves inside the package.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests can use the GitHub issue forms included in this repository.

## License

This collection is licensed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
