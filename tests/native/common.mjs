// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * @file common.mjs
 * Paths and process helpers of the native tests: the built archives in dist/, the pinned STruC++ in node_modules and
 * the HMI core fetched by `npm run setup:hmi-core` (or the editor checkout named by HMI_CORE_EDITOR_DIR).
 */
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
export const STRUCPP = join(ROOT, 'node_modules', 'strucpp')
export const RUNTIME_INCLUDE = join(STRUCPP, 'src', 'runtime', 'include')
export const CXX = { gcc: 'g++', clang: 'clang++', cc: 'c++' }

/** The editor tree the HMI core comes from: HMI_CORE_EDITOR_DIR, else the commit hmi-core.json pins. */
export function editorTree() {
  if (process.env.HMI_CORE_EDITOR_DIR) return process.env.HMI_CORE_EDITOR_DIR
  const { source } = JSON.parse(readFileSync(join(ROOT, 'hmi-core.json'), 'utf8'))
  const dir = join(ROOT, '.cache', 'hmi-core', source.ref)
  if (!existsSync(join(dir, 'resources', 'sources', 'hmi', 'core', 'hmi_core.h')))
    throw new Error('The HMI core is not fetched: run npm run setup:hmi-core')
  return dir
}

/** Loads STruC++ and an archive of dist/ through its archive parser, as every consumer loads it. */
export async function loadArchive(name) {
  const file = join(ROOT, 'dist', `${name}.stlib`)
  if (!existsSync(file)) throw new Error(`dist/${name}.stlib is missing: run npm run build`)
  const strucpp = await import(join(STRUCPP, 'dist', 'index.js'))
  return { strucpp, archive: strucpp.loadStlibFromString(readFileSync(file, 'utf8'), name) }
}

export function run(cmd, args, options = {}) {
  const r = spawnSync(cmd, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options })
  if (r.error) throw r.error
  return r
}

export function must(r, what) {
  if (r.status !== 0) {
    process.stderr.write(r.stdout ?? '')
    process.stderr.write(r.stderr ?? '')
    throw new Error(`${what} failed (exit ${r.status})`)
  }
  return r.stdout
}
