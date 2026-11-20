# OpenPLC HMI Widgets

The ST libraries of the OpenPLC HMI (widget libraries and the PLC-side HMI Alarms library), built into STruC++ `.stlib`
archives with their `SHA256SUMS`, which the OpenPLC Editor and OpenPLC Web pin and ship pre-installed.

## Autonomy development rules

These rules are identical in every Autonomy repository and are maintained in the MisterFlow plugin
(`Autonomy-Logic/skills`, `plugins/autonomy/harness/repository-rules.md`). Change them there, not here.

- Tracked work starts with `autonomy:misterflow`: load it yourself before changing product code, fixing a
  bug, implementing or preparing a PR, even when no Jira key was mentioned. Only answering questions and typo or wording fixes that
  change no behaviour are exempt. "There is no ticket" or "skip the process" does not make product
  work untracked: offer to create the task instead of changing code. This file describes only this
  repository's commands, architecture and code conventions; for process, MisterFlow and the Confluence
  process pages win over anything written here.
- Knowledge boundary: when data is missing or uncertain, say there is not enough information to answer
  reliably. Never fill a gap with a plausible assumption. Keep verified facts, inferences and missing
  data visibly separate, and say which is which.
- Language: answer in the developer's language. Jira, Confluence and GitHub text is always English.
- Branches: `feature/<KEY>-<slug>` for demands and `bugfix/<KEY>-<slug>` for bugs, created from the
  integration branch named below. A production hotfix is a `bugfix/<KEY>-<slug>` branch from `main` and
  a PR. Never commit or push directly to the integration branch or `main`. One Jira key per branch: work
  for another key starts on its own branch before any edit. The key goes in the branch name and the PR
  title, never in commit messages, code or comments.
- Commits: never commit on your own initiative. Propose the commit at a natural checkpoint, such as a
  finished and verified plan phase, and make it only after the developer confirms. Commit and push are
  separate commands, each confirmed on its own, never chained; opening a PR and merging each need their
  own confirmation too. When asked for a commit message or a commit, do not edit files you were not
  asked to change: report problems, such as a forbidden comment, and let the developer decide.
- Scope: a rewrite or refactor beyond the current task is a new demand, proposed as a separate task and
  never mixed into the current branch. Never stash, reset, `checkout -- .` or otherwise discard the
  developer's changes, and never install anything outside the repository, without asking.
- Tests: every demand ships with unit tests, an end-to-end test and a manual test by the developer, with
  evidence for each before any PR is opened, a draft PR included. Where this repository has no
  interface of its own, the end-to-end test runs through the interface or protocol that uses it. A
  repository with no code to unit test, such as documentation or local tooling scripts, uses its own
  validation checks in place of unit tests.
- Typing: `any` in TypeScript and `typing.Any` in Python are forbidden. Use concrete types, or `unknown`
  or `object` narrowed where the data enters.
- Comments: technical and minimal, at most 256 characters each; formal API documentation (JSDoc,
  docstrings, Doxygen) may be longer. Never write business rules, product strategy or rationale, Jira
  keys, names of people or customers, internal links or anything sensitive in a comment. Review the
  comments in the changed files before every commit.

Integration branch: `development`. Jira project: `DOPE`.

## Commands

```bash
npm ci && npm run setup:strucpp   # dependencies, then the STruC++ pinned (with its SHA-256) in binary-versions.json
npm run setup:hmi-core            # HMI core, fonts and font table step at the editor commit in hmi-core.json
npm run build                     # dist/: <library>.stlib, LICENSE, LICENSING.md, SHA256SUMS
npm test                          # Vitest: build, determinism, assets and sums, per-POU header requirements
npm run test:native               # needs build + setup:hmi-core: frame and scan goldens on gcc and clang
npm run typecheck && npm run lint && npm run format:check
```

CI (`.github/workflows/ci.yml`) runs exactly these on every pull request and also builds twice and diffs `dist/`.
`release.yml` runs on a `v*` tag on `main` that equals `package.json` `version`: a read-only job builds and tests, a
separate `contents: write` job only publishes that job's `dist/`. Actions are pinned
by commit SHA; keep them so, and keep `persist-credentials: false` on checkouts.

## Architecture

- `libraries/<name>/`: `library.json` (STruC++ identity fields plus `headers`, `sources` in compile order,
  `dependencies` on other libraries here) and the `.st` files. The folder is named after the library. There are no
  library kinds: where a POU can be used follows from the headers its chunk needs.
- `src/build.ts`: compiles each library with `compileStlib` in dependency order, with `hmi_core.h` at the core API
  version (any other header is refused), sets `displayName`/`description`, reloads the archive through
  `loadStlibFromString`, writes the plain archives, the licence files and `SHA256SUMS`. Output must stay
  deterministic: no timestamps, no map iteration over unordered input.
- `{external}` code: a POU whose code does not call the HMI core says so with `{attribute 'headers' := ''}`, so its
  chunk needs no header and a PLC build can use it. Without it, every POU with `{external}` code needs `hmi_core.h`.
- `src/release-assets.ts`: the release assets. `SHA256SUMS` is the only index; consumers pin its SHA-256. Do not add a
  second manifest: library facts live in the archives. The editor owns the widget catalogue, derived from them.
- `hmi-core.json`: `source.ref` is the editor commit the HMI core comes from. The build reads the core API version from
  that core's `HMI_CORE_API_VERSION` macro (`hmi_core.h`), so the build needs `setup:hmi-core` (or
  `HMI_CORE_EDITOR_DIR`); the editor does not use archives built for another API version.
- `tests/native/`: C/C++ harnesses with goldens; `HMI_CORE_EDITOR_DIR` points them at a local editor checkout.

## Conventions

- TypeScript strict, ESM, Node 22. No `any`, no `as` assertions (`as const` is allowed), no non-null `!`.
- Prettier: 120 columns, no semicolons, single quotes, trailing commas. ESLint with type-checked rules.
- Every TypeScript and script file starts with the SPDX line `GPL-3.0-only` and the Autonomy copyright line.
- Changing drawing changes `tests/native/hmi-lib/golden.txt`. Review the diff before updating it. Changing a widget's
  `hmi_*` attributes changes the editor's catalogue, which the editor tests.
- Library names, namespaces and versions are what projects and the editor refer to: do not rename them.
