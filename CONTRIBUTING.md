# Contributing

Thank you for helping improve this ipelet collection.

## Before opening a change

1. Keep each change focused on one ipelet or one repository-wide concern.
2. Preserve the single-file runtime distribution of each ipelet.
3. Keep development tools and automation outside the runtime `.lua` file.
4. Add a regression test for behavior changes whenever practical.
5. Update the relevant changelog and documentation.

## Local checks

Install Python 3, Lua 5.4, and the Lua 5.4 compiler, then run:

```bash
./scripts/validate.sh
```

For a focused Circles check:

```bash
luac5.4 -p circles/circles.lua
python3 -m unittest discover -s circles/tests -v
```

## Visual changes

When a change affects generated geometry or dialogs:

- test it in a real Ipe installation;
- update the editable `.ipe` example when the visible result changes;
- regenerate the SVG and PNG documentation images;
- inspect the exported images rather than relying only on file creation.

## Pull requests

Describe the behavior change, the checks that were actually run, and any compatibility limitations. Do not include generated caches, temporary files, local configuration, or private development infrastructure.
