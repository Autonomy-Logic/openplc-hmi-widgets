# OpenPLC HMI Widgets

The ST libraries of the OpenPLC HMI, released as native [STruC++](https://github.com/Autonomy-Logic/STruCpp) `.stlib`
archives. The OpenPLC Editor and OpenPLC Web download a pinned release and ship its archives pre-installed: they cannot
be removed, and further widget libraries install through the editor's library manager.

| Library                                   | What it is                                                                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `standard-widgets` (HMI Standard Widgets) | Element base, primitives, containers, display widgets, controls, process symbols, data widgets, keyboard, screen base and runtime                                  |
| `hmi-alarms` (HMI Alarms)                 | `HMI_ALARM`, `HMI_ALARMS`, `HMI_ALARM_LOGGER`, `HMI_LOG_EVENT`, `HMI_ALARM_ROW`, `HMI_ALARM_SUMMARY`, `HMI_EVENT_ROW`: the PLC side of the alarm and event widgets |

Every archive is a plain STruC++ library; there are no library kinds. Each chunk (POU) of an archive records the
headers it needs, so a consumer decides per POU where it can be used: a POU that needs `hmi_core.h` only in an HMI
build, a POU that needs no header in a PLC build as well. Every POU of `hmi-alarms` needs no header.

## Layout

```
libraries/<name>/library.json   identity, headers, sources in compile order, dependencies
libraries/<name>/*.st           the ST source
src/                            the build: release manifest, library configuration
scripts/                        setup-strucpp, fetch-hmi-core, build
tests/                          unit tests (Vitest) and the native frame tests (tests/native/)
binary-versions.json            the pinned STruC++ release and the SHA-256 of its tarball
hmi-core.json                   the editor commit the HMI core (its API version, and the native tests' core) comes from
```

`standard-widgets` is one archive. Its categories all extend `HmiElement`, draw through the screen runtime, use the
`COLOR` constant and the keyboard, and the editor compiles screens against the library as a whole; split archives
would each depend on a base archive and add load and dependency handling without letting anyone use a category alone.

## Build

```bash
npm ci
npm run setup:strucpp      # the STruC++ pinned in binary-versions.json, checked against its SHA-256
npm run setup:hmi-core     # the HMI core at the editor commit hmi-core.json pins
npm run build              # dist/: one .stlib per library, openplc-hmi-widgets.json, SHA256SUMS
```

The build refuses any STruC++ but the pinned one, and two builds are byte-identical.

## Release assets

- `<library>.stlib`: a plain STruC++ archive (format 1). Its `dependencies` lists the libraries its code uses, and
  each chunk's `headers` the headers that chunk needs, transitively, with their API version (`hmi_core.h` at the HMI
  core API version). The editor derives the widget catalogue from the archive's manifest, which carries the `hmi_*`
  attribute pragmas of the source.

- `openplc-hmi-widgets.json`, the release manifest (format 2):

  ```json
  {
    "formatVersion": 2,
    "name": "openplc-hmi-widgets",
    "version": "1.0.0",
    "strucppVersion": "0.8.1-rc1",
    "archives": [
      {
        "name": "standard-widgets",
        "displayName": "HMI Standard Widgets",
        "version": "1.0.0",
        "file": "standard-widgets.stlib",
        "sha256": "…",
        "size": 0,
        "strucppVersion": "0.8.1-rc1",
        "headers": ["hmi_core.h"],
        "license": "GPL-3.0-only OR LicenseRef-Autonomy-Commercial"
      }
    ]
  }
  ```

- `SHA256SUMS`, and `LICENSE` and `LICENSING.md`.

## HMI core API version

Widget code calls the HMI C core (`hmi_core.h`), which lives in the OpenPLC Editor and defines its API version as the
`HMI_CORE_API_VERSION` macro. The build reads that macro from the core at the editor commit `hmi-core.json` pins (or
from `HMI_CORE_EDITOR_DIR`) and compiles every library that lists `hmi_core.h` against that version, so the archive's
`manifest.headerVersions` and each chunk that needs the core carry it. `hmi_core.h` is the only header with a known API
version; the build refuses any other header in `library.json`. The editor does not use a POU that needs another core
API version than its own. To move to a new core API, pin `hmi-core.json` to the editor commit that
raises the macro.

## Tests

```bash
npm run setup:hmi-core     # fetch the HMI core, fonts and font table step at the editor commit hmi-core.json pins
npm test                   # archives load, two builds are identical, manifest and sums, per-POU header requirements
npm run build && npm run test:native
```

`test:native` builds `tests/native/hmi-lib` (test screens against `dist/standard-widgets.stlib`, with the HMI C core,
on gcc, clang and a sanitized build) and `tests/native/hmi-alarms` (a scripted program against
`dist/hmi-alarms.stlib`), and compares their output with `golden.txt`. Set `HMI_CORE_EDITOR_DIR` to an editor checkout
to test against its core instead of the pinned commit.

## Releasing

Set `version` in `package.json`, merge to `main`, then push the tag `v<version>` on a commit of `main`. `release.yml`
builds twice and runs every test in a read-only job, then a separate job with write access publishes the assets it
built with their SHA-256 sums. It refuses a tag that is not on `main` or does not match `package.json`. The editor and OpenPLC Web pin the release in
`binary-versions.json`, with the SHA-256 of `openplc-hmi-widgets.json`.

## Licence

Dual-licensed: GPLv3 or a commercial licence from Autonomy Logic Inc.; see [LICENSING.md](LICENSING.md).
Contributions require agreeing to the [Contributor License Agreement](CLA.md); see [CONTRIBUTING.md](CONTRIBUTING.md).
