// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

import { parse } from 'strucpp'
import { beforeAll, describe, expect, it } from 'vitest'

import { buildRelease } from '../src/build.js'
import type { HmiWidgetCatalog } from '../src/catalog-types.js'
import { readLibraries } from '../src/build.js'
import { ROOT } from '../scripts/pins.js'

interface SourceBlock {
  name: string
  extends?: string
  isAbstract: boolean
  palette?: string
}

/** Function blocks of a library's sources, read from the parser's AST and not from the compiled manifest. */
function sourceBlocks(library: string): SourceBlock[] {
  const lib = readLibraries(ROOT).find((l) => l.config.name === library)
  if (!lib) throw new Error(`no library ${library}`)
  return lib.config.sources.flatMap((fileName) => {
    const { ast, errors } = parse(readFileSync(join(lib.dir, fileName), 'utf8'))
    if (errors.length > 0 || !ast) throw new Error(`${fileName} does not parse`)
    return ast.functionBlocks.map((fb) => ({
      name: fb.name,
      extends: fb.extends,
      isAbstract: fb.isAbstract,
      palette: fb.attributes?.find((a) => a.name === 'hmi_palette')?.value,
    }))
  })
}

let catalog: HmiWidgetCatalog

beforeAll(() => {
  const widgets = buildRelease({ root: ROOT }).manifest.archives.find((a) => a.name === 'standard-widgets')
  if (widgets?.kind !== 'hmi') throw new Error('standard-widgets is not an hmi archive')
  catalog = widgets.catalog
})

describe('standard-widgets catalogue', () => {
  it('lists exactly the concrete blocks that extend HmiElement, with their palette group', () => {
    const blocks = sourceBlocks('standard-widgets')
    const byName = new Map(blocks.map((b) => [b.name.toUpperCase(), b]))
    const isWidget = (b: SourceBlock): boolean => {
      let current: SourceBlock | undefined = b
      const seen = new Set<string>()
      while (current?.extends && !seen.has(current.name)) {
        seen.add(current.name)
        if (current.extends.toUpperCase() === 'HMIELEMENT') return true
        current = byName.get(current.extends.toUpperCase())
      }
      return false
    }
    const expected = blocks.filter((b) => !b.isAbstract && isWidget(b))
    expect(catalog.widgets.map((w) => w.name.toUpperCase()).sort()).toEqual(
      expected.map((b) => b.name.toUpperCase()).sort(),
    )
    for (const b of expected) {
      const widget = catalog.widgets.find((w) => w.name.toUpperCase() === b.name.toUpperCase())
      expect(widget?.palette, b.name).toBe(b.palette)
      expect(widget?.library).toBe('standard-widgets')
    }
  })

  it('reads the COLOR constant fields, theme colors first', () => {
    expect(catalog.colors.slice(0, 3)).toEqual(['Background', 'Surface', 'Text'])
    expect(catalog.colors).toContain('Transparent')
  })

  it('derives bindings, ranges, series and sources from the attributes', () => {
    const widget = (name: string) => catalog.widgets.find((w) => w.name === name)
    expect(widget('HmiButton')?.momentary).toBeDefined()
    expect(widget('HmiSlider')?.twoWay).toMatchObject({ changed: 'Changed', newValue: 'NewValue' })
    expect(catalog.widgets.some((w) => w.series !== undefined)).toBe(true)
    expect(catalog.widgets.some((w) => (w.sources ?? []).length > 0)).toBe(true)
  })

  it('matches the committed catalogue', async () => {
    await expect(`${JSON.stringify(catalog, null, 2)}\n`).toMatchFileSnapshot(
      './__snapshots__/standard-widgets.catalog.json',
    )
  })
})
