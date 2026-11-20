# OpenPLC HMI Widgets

The ST libraries of the OpenPLC HMI, released as native [STruC++](https://github.com/Autonomy-Logic/STruCpp) `.stlib`
archives. The OpenPLC Editor and OpenPLC Web download a pinned release and ship its archives pre-installed: they cannot
be removed, and further widget libraries install through the editor's library manager.

| Library                                   | Kind  | What it is                                                                                                                                                         |
| ----------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `standard-widgets` (HMI Standard Widgets) | `hmi` | Element base, primitives, containers, display widgets, controls, process symbols, data widgets, keyboard, screen base and runtime                                  |
| `hmi-alarms` (HMI Alarms)                 | `plc` | `HMI_ALARM`, `HMI_ALARMS`, `HMI_ALARM_LOGGER`, `HMI_LOG_EVENT`, `HMI_ALARM_ROW`, `HMI_ALARM_SUMMARY`, `HMI_EVENT_ROW`: the PLC side of the alarm and event widgets |

A library of kind `hmi` feeds the HMI designer's palette and the HMI build; a library of kind `plc` is a PLC library
like any other and shows in the editor's PLC library panel.

## Layout

```
libraries/<name>/library.json   identity, kind, headers, sources in compile order, dependencies
libraries/<name>/*.st           the ST source
src/                            the build: catalogue, release manifest, library configuration
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

- `<library>.stlib`: a STruC++ archive (format 1) with one extra top-level key, `openplc`, that STruC++ ignores:

  ```json
  {
    "formatVersion": 1,
    "kind": "hmi",
    "license": "GPL-3.0-only OR LicenseRef-Autonomy-Commercial",
    "hmiCoreApi": 1,
    "catalog": { "widgets": [], "colors": [] }
  }
  ```

  `hmiCoreApi` and `catalog` are present for kind `hmi` only. The editor reads the archive alone, so a widget library a
  user installs carries everything the editor needs.

- `openplc-hmi-widgets.json`, the release manifest (format 1):

  ```json
  {
    "formatVersion": 1,
    "name": "openplc-hmi-widgets",
    "version": "1.0.0",
    "strucppVersion": "0.8.1-rc1",
    "archives": [
      {
        "name": "standard-widgets",
        "displayName": "HMI Standard Widgets",
        "version": "1.0.0",
        "kind": "hmi",
        "file": "standard-widgets.stlib",
        "sha256": "…",
        "size": 0,
        "strucppVersion": "0.8.1-rc1",
        "headers": ["hmi_core.h"],
        "license": "GPL-3.0-only OR LicenseRef-Autonomy-Commercial",
        "hmiCoreApi": 1,
        "catalog": { "widgets": [], "colors": [] }
      }
    ]
  }
  ```

  The catalogue (palette groups, defaults, colours, preview values, ranges, requirements, data sources, series,
  inputs with their types and attributes) is generated from the archive's STruC++ manifest, which carries the
  `hmi_*` attribute pragmas of the source; `src/catalog-types.ts` documents each field.

- `SHA256SUMS`, and `LICENSE` and `LICENSING.md`.

## HMI core API version

Widget code calls the HMI C core (`hmi_core.h`), which lives in the OpenPLC Editor and defines its API version as the
`HMI_CORE_API_VERSION` macro. The build reads that macro from the core at the editor commit `hmi-core.json` pins (or
from `HMI_CORE_EDITOR_DIR`); every `hmi` archive records it as `hmiCoreApi`, and the editor does not use a widget
library built for another core API version. To move to a new core API, pin `hmi-core.json` to the editor commit that
raises the macro.

## Tests

```bash
npm run setup:hmi-core     # fetch the HMI core, fonts and font table step at the editor commit hmi-core.json pins
npm test                   # archives load, two builds are identical, manifest and sums, catalogue vs. the sources
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
