// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * Writes the HMI font table for the native tests with the editor's font build step, from the editor tree the tests
 * use. Usage: tsx tests/native/font-table.ts <editor-tree> <out.c> [all|regular|none] [full|compact]
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

interface VettedFont {
  id: number
  variant: string
  file: string
}

function isVettedList(value: unknown): value is VettedFont[] {
  return (
    Array.isArray(value) &&
    value.every(
      (f: unknown) =>
        typeof f === 'object' &&
        f !== null &&
        'id' in f &&
        'variant' in f &&
        'file' in f &&
        typeof f.id === 'number' &&
        typeof f.variant === 'string' &&
        typeof f.file === 'string',
    )
  )
}

async function main(): Promise<void> {
  const [tree, out, faces = 'all', variant = 'compact'] = process.argv.slice(2)
  if (!tree || !out || !['all', 'regular', 'none'].includes(faces) || !['full', 'compact'].includes(variant))
    throw new Error('usage: font-table.ts <editor-tree> <out.c> [all|regular|none] [full|compact]')
  const fontsCode = join(tree, 'src', 'backend', 'shared', 'hmi', 'fonts')
  const vetted: unknown = await import(pathToFileURL(join(fontsCode, 'vetted-fonts.ts')).href)
  const table: unknown = await import(pathToFileURL(join(fontsCode, 'font-table-source.ts')).href)
  const exported = (module: unknown, name: string): unknown =>
    typeof module === 'object' && module !== null ? Reflect.get(module, name) : undefined
  const list = exported(vetted, 'VETTED_HMI_FONTS')
  const build = exported(table, 'buildHmiFontTableSource')
  const regular = exported(vetted, 'HMI_FONT_REGULAR')
  if (!isVettedList(list) || typeof build !== 'function' || typeof regular !== 'number')
    throw new Error(`${fontsCode} does not export the font build step`)
  const fontDir = join(tree, 'resources', 'sources', 'hmi', 'fonts')
  const fonts = list
    .filter((f) => f.variant === variant && (faces === 'all' || (faces === 'regular' && f.id === regular)))
    .map((f) => ({ id: f.id, variant: f.variant, bytes: new Uint8Array(readFileSync(join(fontDir, f.file))) }))
  const source: unknown = await Reflect.apply(build, undefined, [fonts])
  if (typeof source !== 'string') throw new Error('the font build step returned no source')
  writeFileSync(out, source)
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
})
