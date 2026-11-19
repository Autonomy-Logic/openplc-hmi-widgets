// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * Fetches what the native tests need from the OpenPLC Editor at the commit `hmi-core.json` pins: the HMI C core, the
 * vetted fonts and the font table generator. They land in `.cache/hmi-core/<ref>/`, laid out as in the editor.
 * With `HMI_CORE_EDITOR_DIR` set to an editor checkout, the tests use that checkout instead and nothing is fetched.
 *
 *   tsx scripts/fetch-hmi-core.ts
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, rmSync } from 'node:fs'
import { join } from 'node:path'

import { readHmiCoreConfig } from '../src/build.js'
import { ROOT } from './pins.js'

/** Editor paths the native tests read. */
export const HMI_CORE_PATHS = [
  'resources/sources/hmi/core',
  'resources/sources/hmi/fonts',
  'src/backend/shared/hmi/fonts/font-table-source.ts',
  'src/backend/shared/hmi/fonts/vetted-fonts.ts',
] as const

function git(cwd: string, args: string[]): void {
  execFileSync('git', args, { cwd, stdio: ['ignore', 'ignore', 'inherit'] })
}

function main(): void {
  if (process.env.HMI_CORE_EDITOR_DIR) {
    console.log(`[fetch-hmi-core] HMI_CORE_EDITOR_DIR is set: the tests use ${process.env.HMI_CORE_EDITOR_DIR}`)
    return
  }
  const { source } = readHmiCoreConfig(ROOT)
  const dir = join(ROOT, '.cache', 'hmi-core', source.ref)
  if (existsSync(join(dir, HMI_CORE_PATHS[0], 'hmi_core.h'))) {
    console.log(`[fetch-hmi-core] ${source.repository}@${source.ref} already fetched`)
    return
  }
  rmSync(dir, { recursive: true, force: true })
  mkdirSync(dir, { recursive: true })
  try {
    git(dir, ['init', '-q'])
    git(dir, ['remote', 'add', 'origin', `https://github.com/${source.repository}.git`])
    git(dir, ['sparse-checkout', 'set', '--no-cone', ...HMI_CORE_PATHS.map((p) => `/${p}`)])
    git(dir, ['fetch', '-q', '--depth', '1', '--filter=blob:none', 'origin', source.ref])
    git(dir, ['checkout', '-q', 'FETCH_HEAD'])
  } catch (error) {
    rmSync(dir, { recursive: true, force: true })
    throw error
  }
  for (const path of HMI_CORE_PATHS)
    if (!existsSync(join(dir, path))) throw new Error(`${source.repository}@${source.ref} has no ${path}`)
  console.log(`[fetch-hmi-core] ${source.repository}@${source.ref} fetched into ${dir}`)
}

try {
  main()
} catch (error: unknown) {
  console.error(`[fetch-hmi-core] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
}
