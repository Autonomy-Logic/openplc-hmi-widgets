# OpenPLC HMI Widgets

The ST libraries of the OpenPLC HMI (widget libraries and the PLC-side HMI Alarms library), built into STruC++ `.stlib`
archives with a release manifest that the OpenPLC Editor and OpenPLC Web pin and ship pre-installed.

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
npm ci && npm run setup:strucpp   # dependencies, then the STruC++ pinned in binary-versions.json (npm ci removes it)
npm run setup:hmi-core            # HMI core, fonts and font table step at the editor commit in hmi-core.json
npm run build                     # dist/: <library>.stlib, openplc-hmi-widgets.json, SHA256SUMS
npm test                          # Vitest: build, determinism, manifest, catalogue vs. sources
npm run test:native               # needs build + setup:hmi-core: frame and scan goldens on gcc and clang
npm run typecheck && npm run lint && npm run format:check
```

CI (`.github/workflows/ci.yml`) runs exactly these on every pull request and also builds twice and diffs `dist/`.
`release.yml` runs on a `v*` tag that equals `package.json` `version` and publishes `dist/` with `LICENSE` and
`LICENSING.md`.

## Architecture

- `libraries/<name>/`: `library.json` (STruC++ identity fields plus `kind`, `headers`, `sources` in compile order,
  `dependencies` on other libraries here) and the `.st` files. The folder is named after the library.
- `src/build.ts`: compiles each library with `compileStlib` in dependency order, sets `displayName`/`description`,
  reloads the archive through `loadStlibFromString`, adds the `openplc` metadata key, writes the release manifest and
  `SHA256SUMS`. Output must stay deterministic: no timestamps, no map iteration over unordered input.
- `src/catalog.ts`: the widget catalogue from a compiled manifest's `hmi_*` attributes. Its output is a contract with
  the editor (`src/catalog-types.ts`); the editor computes the same catalogue for a project's own widget blocks, so a
  change here needs the matching change there.
- `src/release-manifest.ts`: release manifest and archive metadata formats. Bump `RELEASE_MANIFEST_FORMAT` or
  `ARCHIVE_METADATA_FORMAT` for any incompatible change; consumers refuse formats they do not know.
- `hmi-core.json`: `apiVersion` is the HMI core API the widget code calls; the editor defines the same number
  (`HMI_CORE_API_VERSION`) and refuses archives built for another one. `source.ref` is the editor commit the native
  tests take the core from. Change both together when the core API changes.
- `tests/native/`: C/C++ harnesses with goldens; `HMI_CORE_EDITOR_DIR` points them at a local editor checkout.

## Conventions

- TypeScript strict, ESM, Node 22. No `any`, no `as` assertions (`as const` is allowed), no non-null `!`.
- Prettier: 120 columns, no semicolons, single quotes, trailing commas. ESLint with type-checked rules.
- Every TypeScript and script file starts with the SPDX line `GPL-3.0-only` and the Autonomy copyright line.
- Changing a widget's attributes changes `tests/__snapshots__/standard-widgets.catalog.json`; changing drawing changes
  `tests/native/hmi-lib/golden.txt`. Review the diff before updating either.
- Library names, namespaces and versions are what projects and the editor refer to: do not rename them.
