// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * Writes the release assets to `dist/`: one .stlib per library, `openplc-hmi-widgets.json` and `SHA256SUMS`. Refuses
 * to build with a STruC++ other than the pinned one.
 *
 *   tsx scripts/build.ts [--out <dir>]
 */
import { mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'

import { getVersion } from 'strucpp'

import { buildRelease } from '../src/build.js'
import { pinnedStrucpp, ROOT } from './pins.js'

function outDir(): string {
  const i = process.argv.indexOf('--out')
  return i >= 0 && process.argv[i + 1] ? resolve(process.argv[i + 1]) : join(ROOT, 'dist')
}

function main(): void {
  const pinned = pinnedStrucpp().version.replace(/^v/, '')
  if (getVersion() !== pinned)
    throw new Error(`STruC++ ${getVersion()} is installed but ${pinned} is pinned: run npm run setup:strucpp`)
  const { files, manifest } = buildRelease({ root: ROOT })
  const out = outDir()
  rmSync(out, { recursive: true, force: true })
  mkdirSync(out, { recursive: true })
  for (const [name, text] of files) writeFileSync(join(out, name), text)
  for (const a of manifest.archives) console.log(`${a.file}  ${a.sha256}`)
  console.log(`[build] openplc-hmi-widgets ${manifest.version} written to ${out}`)
}

try {
  main()
} catch (error: unknown) {
  console.error(`[build] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
}
