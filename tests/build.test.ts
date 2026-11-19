// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

import { getVersion, loadStlibFromString } from 'strucpp'
import { beforeAll, describe, expect, it } from 'vitest'

import { buildRelease, type BuildOutput, readHmiCoreConfig, readLibraries } from '../src/build.js'
import {
  LIBRARY_LICENSE,
  RELEASE_MANIFEST_FILE,
  RELEASE_MANIFEST_FORMAT,
  SHA256SUMS_FILE,
} from '../src/release-manifest.js'
import { sha256Hex } from '../src/sha256.js'
import { pinnedStrucpp, ROOT } from '../scripts/pins.js'

let first: BuildOutput

beforeAll(() => {
  first = buildRelease({ root: ROOT })
})

function archiveText(name: string): string {
  const text = first.files.get(`${name}.stlib`)
  if (text === undefined) throw new Error(`no ${name}.stlib`)
  return text
}

describe('release build', () => {
  it('uses the pinned STruC++', () => {
    expect(getVersion()).toBe(pinnedStrucpp().version.replace(/^v/, ''))
    expect(first.manifest.strucppVersion).toBe(getVersion())
  })

  it('is byte-identical across builds', () => {
    const second = buildRelease({ root: ROOT })
    expect([...second.files.keys()]).toEqual([...first.files.keys()])
    for (const [name, text] of first.files) expect(second.files.get(name), name).toBe(text)
  })

  it('writes one archive per library, the manifest and the sums', () => {
    const names = readLibraries(ROOT).map((l) => `${l.config.name}.stlib`)
    expect([...first.files.keys()].sort()).toEqual([...names, RELEASE_MANIFEST_FILE, SHA256SUMS_FILE].sort())
  })

  it('archives load through the STruC++ archive parser', () => {
    for (const a of first.manifest.archives) {
      const archive = loadStlibFromString(archiveText(a.name), a.file)
      expect(archive.manifest.name).toBe(a.name)
      expect(archive.manifest.version).toBe(a.version)
      expect(archive.manifest.headers).toEqual(a.headers)
      expect(archive.chunks.length).toBeGreaterThan(0)
    }
  })

  it('describes every archive with its hash, size and kind', () => {
    const { manifest } = first
    expect(manifest.formatVersion).toBe(RELEASE_MANIFEST_FORMAT)
    const pkg: unknown = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'))
    expect(pkg).toMatchObject({ version: manifest.version })
    for (const a of manifest.archives) {
      const text = archiveText(a.name)
      expect(a.sha256).toBe(sha256Hex(text))
      expect(a.size).toBe(Buffer.byteLength(text))
      expect(a.license).toBe(LIBRARY_LICENSE)
      const parsed: unknown = JSON.parse(text)
      expect(parsed).toMatchObject({ openplc: { formatVersion: 1, kind: a.kind, license: LIBRARY_LICENSE } })
    }
    expect(JSON.parse(first.files.get(RELEASE_MANIFEST_FILE) ?? '')).toEqual(manifest)
  })

  it('marks the widget library hmi with the core API it needs, and the alarms library plc', () => {
    const core = readHmiCoreConfig(ROOT)
    const widgets = first.manifest.archives.find((a) => a.name === 'standard-widgets')
    const alarms = first.manifest.archives.find((a) => a.name === 'hmi-alarms')
    expect(widgets).toMatchObject({ kind: 'hmi', hmiCoreApi: core.apiVersion, headers: ['hmi_core.h'] })
    expect(alarms).toMatchObject({ kind: 'plc', headers: [], displayName: 'HMI Alarms' })
    expect(JSON.parse(archiveText('standard-widgets'))).toMatchObject({
      openplc: { kind: 'hmi', hmiCoreApi: core.apiVersion },
    })
  })

  it('lists every file in SHA256SUMS', () => {
    const sums = (first.files.get(SHA256SUMS_FILE) ?? '').trim().split('\n')
    const listed = new Map(sums.map((line) => [line.slice(66), line.slice(0, 64)]))
    for (const [name, text] of first.files) if (name !== SHA256SUMS_FILE) expect(listed.get(name)).toBe(sha256Hex(text))
    expect(listed.size).toBe(first.files.size - 1)
  })
})
