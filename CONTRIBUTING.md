# Contributing

## Licensing and the Contributor License Agreement

The OpenPLC HMI widget libraries are dual-licensed under the GPLv3 and a commercial licence (see [LICENSING.md](LICENSING.md)).

- **Contributor License Agreement.** By ticking the Contributor License Agreement checkbox in the pull request template, you agree that your contribution is licensed to Autonomy Logic Inc. under the terms of the [Contributor License Agreement](CLA.md). The CLA check fails until the box is ticked. You keep the copyright on your contribution.
- **Always available under the GPLv3.** Every contribution accepted here stays available under the GPLv3, in addition to the commercial licence.
- **SPDX header.** Every new TypeScript or script file starts with `SPDX-License-Identifier: GPL-3.0-only` and the Autonomy copyright line, as in the existing files.
- **Third-party code.** Do not add third-party code unless its licence is compatible with both the GPLv3 and the commercial licence. Ask in the pull request when in doubt.

## Setup

Requires Node.js 22, git, and gcc and clang for the native tests.

```bash
npm ci
npm run setup:strucpp     # the pinned STruC++
npm run setup:hmi-core    # the HMI C core the native tests build against
```

## Workflow

1. Branch from `development`: `feature/<KEY>-<slug>` or `bugfix/<KEY>-<slug>`.
2. Open a pull request against `development` and fill in the template.

## Before pushing

```bash
npm run typecheck && npm run lint && npm run format:check
npm test
npm run build && npm run test:native
```

A change to a widget's attributes changes the committed catalogue in `tests/__snapshots__/`: review it, then update it
with `npx vitest run -u`. A change that moves pixels changes `tests/native/hmi-lib/golden.txt`: review the frames with
`--png <dir>`, then update it with `--update`.
