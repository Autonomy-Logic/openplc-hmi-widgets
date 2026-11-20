// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * Builds the release: each library of `libraries/` compiled into a STruC++ .stlib archive with its `openplc` metadata,
 * the release manifest and the SHA-256 sums. The output depends only on the sources, the configuration and the
 * STruC++ version, so two builds are byte-identical.
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

import { compileStlib, getVersion, type LibraryManifest, loadStlibFromString, type StlibArchive } from 'strucpp'

import { buildWidgetCatalog } from './catalog.js'
import { type LibraryConfig, parseLibraryConfig } from './library-config.js'
import {
  ARCHIVE_METADATA_FORMAT,
  type ArchiveMetadata,
  LIBRARY_LICENSE,
  RELEASE_MANIFEST_FILE,
  RELEASE_MANIFEST_FORMAT,
  type ReleaseArchive,
  type ReleaseManifest,
  SHA256SUMS_FILE,
} from './release-manifest.js'
import { sha256Hex } from './sha256.js'

export interface BuildInput {
  /** Repository root: `libraries/`, `hmi-core.json` and `package.json` are read from it. */
  root: string
  /** Editor tree whose HMI core header gives the core API version; `hmiCoreDir(root)` when absent. */
  coreDir?: string
}

export interface BuildOutput {
  /** Release assets by file name: the archives, the manifest and the sums. */
  files: Map<string, string>
  manifest: ReleaseManifest
}

export interface HmiCoreConfig {
  source: { repository: string; ref: string }
}

/** Path of the HMI core header in an editor tree. */
export const HMI_CORE_HEADER = 'resources/sources/hmi/core/hmi_core.h'

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

/** Reads `hmi-core.json`: the editor repository and commit the HMI core is taken from. */
export function readHmiCoreConfig(root: string): HmiCoreConfig {
  const raw: unknown = JSON.parse(readFileSync(join(root, 'hmi-core.json'), 'utf8'))
  const source = isRecord(raw) ? raw.source : undefined
  if (!isRecord(source) || typeof source.repository !== 'string' || typeof source.ref !== 'string')
    throw new Error('hmi-core.json: "source" must name a repository and a ref')
  return { source: { repository: source.repository, ref: source.ref } }
}

/** The editor tree the HMI core comes from: `HMI_CORE_EDITOR_DIR`, else the commit `hmi-core.json` pins, as fetched. */
export function hmiCoreDir(root: string): string {
  const fromEnv = process.env.HMI_CORE_EDITOR_DIR
  if (fromEnv) return fromEnv
  return join(root, '.cache', 'hmi-core', readHmiCoreConfig(root).source.ref)
}

/** The value of the single `HMI_CORE_API_VERSION` macro in the text of an HMI core header. */
export function parseHmiCoreApiVersion(header: string): number {
  const defines = [...header.matchAll(/^[ \t]*#[ \t]*define[ \t]+HMI_CORE_API_VERSION[ \t]+(\d+)u?[ \t]*$/gm)]
  if (defines.length !== 1)
    throw new Error(`defines HMI_CORE_API_VERSION ${defines.length} times, expected once as a positive integer`)
  const version = Number(defines[0][1])
  if (!Number.isSafeInteger(version) || version < 1) throw new Error('HMI_CORE_API_VERSION must be a positive integer')
  return version
}

/** The HMI core API version the widget libraries are built for: the `HMI_CORE_API_VERSION` macro of the core header. */
export function readHmiCoreApiVersion(coreDir: string): number {
  const file = join(coreDir, HMI_CORE_HEADER)
  if (!existsSync(file)) throw new Error(`${file} is missing: run npm run setup:hmi-core`)
  try {
    return parseHmiCoreApiVersion(readFileSync(file, 'utf8'))
  } catch (error) {
    throw new Error(`${file} ${error instanceof Error ? error.message : String(error)}`)
  }
}

/** The release version, from `package.json`. */
export function readReleaseVersion(root: string): string {
  const raw: unknown = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'))
  if (!isRecord(raw) || typeof raw.version !== 'string') throw new Error('package.json: "version" is missing')
  return raw.version
}

/** The libraries of `libraries/`, each after the libraries it depends on. */
export function readLibraries(root: string): Array<{ dir: string; config: LibraryConfig }> {
  const base = join(root, 'libraries')
  const all = readdirSync(base, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort()
    .map((dir) => {
      const config = parseLibraryConfig(
        readFileSync(join(base, dir, 'library.json'), 'utf8'),
        `libraries/${dir}/library.json`,
      )
      if (config.name !== dir) throw new Error(`libraries/${dir}: the folder must be named after the library`)
      return { dir: join(base, dir), config }
    })
  const byName = new Map(all.map((l) => [l.config.name, l]))
  const ordered: typeof all = []
  const visiting = new Set<string>()
  const visit = (name: string, from: string): void => {
    if (ordered.some((l) => l.config.name === name)) return
    const lib = byName.get(name)
    if (!lib) throw new Error(`${from} depends on "${name}", which is not a library of this repository`)
    if (visiting.has(name)) throw new Error(`libraries depend on each other in a loop through "${name}"`)
    visiting.add(name)
    for (const dep of lib.config.dependencies) visit(dep, name)
    visiting.delete(name)
    ordered.push(lib)
  }
  for (const lib of all) visit(lib.config.name, lib.config.name)
  return ordered
}

function compileLibrary(dir: string, config: LibraryConfig, dependencies: StlibArchive[]): StlibArchive {
  const sources = config.sources.map((fileName) => ({ fileName, source: readFileSync(join(dir, fileName), 'utf8') }))
  const result = compileStlib(sources, {
    name: config.name,
    version: config.version,
    namespace: config.namespace,
    headers: [...config.headers],
    dependencies,
  })
  if (result.errors.length > 0) {
    const where = (e: { file?: string; line?: number }): string =>
      `${e.file ?? config.name}${e.line === undefined ? '' : `:${e.line}`}`
    throw new Error(
      `${config.name} does not compile:\n${result.errors.map((e) => `${where(e)}: ${e.message}`).join('\n')}`,
    )
  }
  return {
    ...result.archive,
    manifest: { ...result.archive.manifest, displayName: config.displayName, description: config.description },
  }
}

/** Builds every library, the release manifest and the sums. */
export function buildRelease(input: BuildInput): BuildOutput {
  const hmiCoreApi = readHmiCoreApiVersion(input.coreDir ?? hmiCoreDir(input.root))
  const version = readReleaseVersion(input.root)
  const strucppVersion = getVersion()
  const loaded = new Map<string, StlibArchive>()
  const files = new Map<string, string>()
  const archives: ReleaseArchive[] = []
  for (const { dir, config } of readLibraries(input.root)) {
    const dependencies = config.dependencies.map((name) => {
      const dep = loaded.get(name)
      if (!dep) throw new Error(`${config.name}: dependency ${name} was not built`)
      return dep
    })
    const archive = compileLibrary(dir, config, dependencies)
    const reloaded = loadStlibFromString(JSON.stringify(archive), config.name)
    loaded.set(config.name, reloaded)
    const metadata: ArchiveMetadata =
      config.kind === 'hmi'
        ? {
            formatVersion: ARCHIVE_METADATA_FORMAT,
            kind: 'hmi',
            license: LIBRARY_LICENSE,
            hmiCoreApi,
            catalog: buildWidgetCatalog(
              reloaded.manifest,
              dependencies.map((d): LibraryManifest => d.manifest),
            ),
          }
        : { formatVersion: ARCHIVE_METADATA_FORMAT, kind: 'plc', license: LIBRARY_LICENSE }
    const file = `${config.name}.stlib`
    const text = JSON.stringify({ ...archive, openplc: metadata })
    files.set(file, text)
    const common = {
      name: config.name,
      displayName: config.displayName,
      version: config.version,
      file,
      sha256: sha256Hex(text),
      size: Buffer.byteLength(text, 'utf8'),
      strucppVersion,
      headers: [...config.headers],
      license: LIBRARY_LICENSE,
    }
    archives.push(
      metadata.kind === 'hmi'
        ? { ...common, kind: 'hmi', hmiCoreApi: metadata.hmiCoreApi, catalog: metadata.catalog }
        : { ...common, kind: 'plc' },
    )
  }
  const manifest: ReleaseManifest = {
    formatVersion: RELEASE_MANIFEST_FORMAT,
    name: 'openplc-hmi-widgets',
    version,
    strucppVersion,
    archives,
  }
  const manifestText = `${JSON.stringify(manifest, null, 2)}\n`
  files.set(RELEASE_MANIFEST_FILE, manifestText)
  const sums = [...files.entries()]
    .map(([name, text]) => `${sha256Hex(text)}  ${name}`)
    .sort((a, b) => a.slice(66).localeCompare(b.slice(66)))
  files.set(SHA256SUMS_FILE, `${sums.join('\n')}\n`)
  return { files, manifest }
}
