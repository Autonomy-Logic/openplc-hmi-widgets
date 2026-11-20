// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'

import {
  chunkHeaders,
  findUnmetRequirements,
  getVersion,
  type HeaderRequirement,
  loadStlibFromString,
  type PouRequirements,
  resolvePouRequirements,
  type StlibArchive,
} from 'strucpp'
import { beforeAll, describe, expect, it } from 'vitest'

import {
  buildRelease,
  type BuildOutput,
  HMI_CORE_HEADER,
  HMI_CORE_HEADER_NAME,
  headerRequirements,
  hmiCoreDir,
  parseHmiCoreApiVersion,
  readHmiCoreApiVersion,
  readLibraries,
} from '../src/build.js'
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

function archive(name: string): StlibArchive {
  return loadStlibFromString(archiveText(name), `${name}.stlib`)
}

function pous(name: string): PouRequirements[] {
  const all = ['standard-widgets', 'hmi-alarms'].map(archive)
  const own = all.find((a) => a.manifest.name === name)
  if (!own) throw new Error(`no archive ${name}`)
  return resolvePouRequirements(own, all)
}

function pou(library: string, name: string): PouRequirements {
  const found = pous(library).find((p) => p.name === name)
  if (!found) throw new Error(`no chunk ${name} in ${library}`)
  return found
}

function usable(p: PouRequirements, providedHeaders: HeaderRequirement[]): boolean {
  return findUnmetRequirements(p.requirements, { providedHeaders }).length === 0
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

  it('describes every archive with its hash and size, in manifest format 2 without kinds or catalogues', () => {
    const { manifest } = first
    expect(manifest.formatVersion).toBe(2)
    expect(RELEASE_MANIFEST_FORMAT).toBe(2)
    const pkg: unknown = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'))
    expect(pkg).toMatchObject({ version: manifest.version })
    for (const a of manifest.archives) {
      const text = archiveText(a.name)
      expect(Object.keys(a).sort()).toEqual(
        ['displayName', 'file', 'headers', 'license', 'name', 'sha256', 'size', 'strucppVersion', 'version'].sort(),
      )
      expect(a.sha256).toBe(sha256Hex(text))
      expect(a.size).toBe(Buffer.byteLength(text))
      expect(a.license).toBe(LIBRARY_LICENSE)
    }
    expect(JSON.parse(first.files.get(RELEASE_MANIFEST_FILE) ?? '')).toEqual(manifest)
  })

  it('writes plain STruC++ archives, with no openplc key', () => {
    for (const a of first.manifest.archives) {
      const parsed: unknown = JSON.parse(archiveText(a.name))
      expect(parsed).not.toHaveProperty('openplc')
      expect(Object.keys(parsed ?? {}).sort()).toEqual(
        ['chunks', 'dependencies', 'formatVersion', 'manifest', 'sources'].sort(),
      )
    }
  })

  it('lists the headers each library includes, hmi_core.h at the core API version', () => {
    const hmiCoreApi = String(readHmiCoreApiVersion(hmiCoreDir(ROOT)))
    const widgets = first.manifest.archives.find((a) => a.name === 'standard-widgets')
    const alarms = first.manifest.archives.find((a) => a.name === 'hmi-alarms')
    expect(widgets).toMatchObject({ displayName: 'HMI Standard Widgets', headers: ['hmi_core.h'] })
    expect(alarms).toMatchObject({ displayName: 'HMI Alarms', headers: [] })
    expect(archive('standard-widgets').manifest.headerVersions).toEqual({ 'hmi_core.h': hmiCoreApi })
    expect(archive('hmi-alarms').manifest.headerVersions).toBeUndefined()
  })

  it('records the libraries each archive uses: none', () => {
    expect(archive('standard-widgets').dependencies).toEqual([])
    expect(archive('hmi-alarms').dependencies).toEqual([])
  })

  it('lists every file in SHA256SUMS', () => {
    const sums = (first.files.get(SHA256SUMS_FILE) ?? '').trim().split('\n')
    const listed = new Map(sums.map((line) => [line.slice(66), line.slice(0, 64)]))
    for (const [name, text] of first.files) if (name !== SHA256SUMS_FILE) expect(listed.get(name)).toBe(sha256Hex(text))
    expect(listed.size).toBe(first.files.size - 1)
  })
})

describe('HMI core API version', () => {
  it('is the HMI_CORE_API_VERSION macro of the core header', () => {
    expect(parseHmiCoreApiVersion('#define HMI_DL_VERSION 1u\n#define HMI_CORE_API_VERSION 3\n')).toBe(3)
    expect(parseHmiCoreApiVersion('  #  define HMI_CORE_API_VERSION 12u\n')).toBe(12)
  })

  it('refuses a header without the macro, with it twice, or with a value that is not a positive integer', () => {
    expect(() => parseHmiCoreApiVersion('#define HMI_DL_VERSION 1u\n')).toThrow('0 times')
    expect(() => parseHmiCoreApiVersion('#define HMI_CORE_API_VERSION 1\n#define HMI_CORE_API_VERSION 2\n')).toThrow(
      '2 times',
    )
    expect(() => parseHmiCoreApiVersion('#define HMI_CORE_API_VERSION 0\n')).toThrow('positive integer')
    expect(() => parseHmiCoreApiVersion('#define HMI_CORE_API_VERSION (1 + 1)\n')).toThrow('0 times')
  })

  it('names the header and the setup step when the core is not fetched', () => {
    expect(() => readHmiCoreApiVersion(join(tmpdir(), 'no-such-editor-tree'))).toThrow('npm run setup:hmi-core')
  })

  it('is stamped on the widget library from the core the build is given', () => {
    const coreDir = mkdtempSync(join(tmpdir(), 'hmi-core-'))
    try {
      const header = join(coreDir, HMI_CORE_HEADER)
      mkdirSync(dirname(header), { recursive: true })
      writeFileSync(header, '#define HMI_CORE_API_VERSION 7\n')
      const { files } = buildRelease({ root: ROOT, coreDir })
      const widgets = loadStlibFromString(files.get('standard-widgets.stlib') ?? '', 'standard-widgets.stlib')
      expect(widgets.manifest.headerVersions).toEqual({ 'hmi_core.h': '7' })
      const element = widgets.chunks.find((c) => c.name === 'HMIELEMENT')
      expect(element?.headers).toEqual([{ name: 'hmi_core.h', version: '7' }])
    } finally {
      rmSync(coreDir, { recursive: true, force: true })
    }
  })
})

describe('header requirements', () => {
  it('versions hmi_core.h only, and refuses a header with no known API version', () => {
    const config = { ...readLibraries(ROOT)[0].config, name: 'x', headers: [HMI_CORE_HEADER_NAME] }
    expect(headerRequirements(config, () => 4)).toEqual([{ name: 'hmi_core.h', version: '4' }])
    expect(headerRequirements({ ...config, headers: [] }, () => 4)).toEqual([])
    expect(() => headerRequirements({ ...config, headers: ['can.h'] }, () => 4)).toThrow('can.h has no known API')
  })

  it('makes the element base and the widgets need hmi_core.h at the core API version', () => {
    const core = { name: 'hmi_core.h', version: String(readHmiCoreApiVersion(hmiCoreDir(ROOT))) }
    for (const name of ['HMIELEMENT', 'HMIBUTTON', 'HMIGAUGE', 'HMISCREEN', 'HMI_FILLRECT']) {
      const p = pou('standard-widgets', name)
      expect(
        p.requirements.filter((r) => r.kind === 'header').map((r) => ({ name: r.name, version: r.version })),
        name,
      ).toEqual([core])
      expect(usable(p, []), name).toBe(false)
      expect(usable(p, [core]), name).toBe(true)
      expect(usable(p, [{ name: 'hmi_core.h', version: `${core.version}0` }]), name).toBe(false)
    }
  })

  it('makes a widget with no external code need the core through the chunks it reaches', () => {
    const button = archive('standard-widgets').chunks.find((c) => c.name === 'HMIBUTTON')
    expect(button?.deps.some((d) => d.name === 'HMIELEMENT')).toBe(true)
    const requirements = pou('standard-widgets', 'HMIBUTTON').requirements
    expect(requirements.length).toBeGreaterThan(0)
    for (const r of requirements) expect(r.via).not.toEqual({ library: 'standard-widgets', name: 'HMIBUTTON' })
  })

  it('leaves the pure types of the widget library free of headers', () => {
    const widgets = archive('standard-widgets')
    const types = widgets.chunks.filter((c) => c.kind === 'type')
    expect(types.map((c) => c.name)).toEqual(expect.arrayContaining(['HMI_ALIGN', 'HMI_COLORS', 'IHMIELEMENT']))
    for (const chunk of types) {
      expect(chunkHeaders(widgets, chunk), chunk.name).toEqual([])
      expect(usable(pou('standard-widgets', chunk.name), []), chunk.name).toBe(true)
    }
  })

  it('leaves external code that does not call the core, and what reaches only it, free of headers', () => {
    const widgets = archive('standard-widgets')
    for (const name of ['HMI_PARSEREAL', 'HMI_DTNANOS', 'HMICALENDAR']) {
      const chunk = widgets.chunks.find((c) => c.name === name)
      expect(chunk && chunkHeaders(widgets, chunk), name).toEqual([])
      expect(usable(pou('standard-widgets', name), []), name).toBe(true)
    }
  })

  it('makes every POU of hmi-alarms usable by a PLC build with no headers', () => {
    const alarms = archive('hmi-alarms')
    expect(alarms.chunks.length).toBeGreaterThan(0)
    for (const chunk of alarms.chunks) expect(chunkHeaders(alarms, chunk), chunk.name).toEqual([])
    for (const p of pous('hmi-alarms')) {
      expect(p.requirements, p.name).toEqual([])
      expect(usable(p, []), p.name).toBe(true)
    }
  })
})
