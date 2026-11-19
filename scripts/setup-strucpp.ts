// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * Installs the STruC++ release pinned in `binary-versions.json` into node_modules, from its GitHub release, the same
 * way the OpenPLC Editor does. Skips the download when the pinned version is already installed.
 *
 *   tsx scripts/setup-strucpp.ts [--force]
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

import { pinnedStrucpp, ROOT } from './pins.js'

function installedVersion(): string | null {
  const pkg = join(ROOT, 'node_modules', 'strucpp', 'package.json')
  if (!existsSync(pkg)) return null
  const raw: unknown = JSON.parse(readFileSync(pkg, 'utf8'))
  return typeof raw === 'object' && raw !== null && 'version' in raw && typeof raw.version === 'string'
    ? raw.version
    : null
}

async function main(): Promise<void> {
  const pin = pinnedStrucpp()
  const version = pin.version.replace(/^v/, '')
  if (!process.argv.includes('--force') && installedVersion() === version) {
    console.log(`[setup-strucpp] strucpp ${pin.version} already installed`)
    return
  }
  const url = `https://github.com/${pin.repository}/releases/download/${pin.version}/strucpp-${version}.tgz`
  console.log(`[setup-strucpp] downloading ${url}`)
  const response = await fetch(url, { redirect: 'follow' })
  if (!response.ok) throw new Error(`could not download ${url}: ${response.status} ${response.statusText}`)
  const tmp = mkdtempSync(join(ROOT, '.tmp-strucpp-'))
  try {
    const tgz = join(tmp, 'strucpp.tgz')
    writeFileSync(tgz, new Uint8Array(await response.arrayBuffer()))
    execFileSync('npm', ['install', tgz, '--no-save'], { cwd: ROOT, stdio: 'inherit' })
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
  if (installedVersion() !== version) throw new Error(`strucpp ${pin.version} did not install`)
  console.log(`[setup-strucpp] strucpp ${pin.version} installed`)
}

main().catch((error: unknown) => {
  console.error(`[setup-strucpp] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
})
