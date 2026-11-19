// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * @file run.mjs
 * Headless frames of the standard-widgets archive: compiles the test screens (screens.st) against dist/
 * standard-widgets.stlib with STruC++, builds them with the HMI C core and driver.cpp on each native compiler, runs the
 * scripted frames and checks the output against golden.txt. Every compiler must print the same lines (display lists
 * and pixels). Needs `npm run build` and `npm run setup:hmi-core` (or HMI_CORE_EDITOR_DIR).
 *
 *   node tests/native/hmi-lib/run.mjs [--cc "gcc clang"] [--sanitize] [--update] [--png DIR]
 *
 * --update rewrites golden.txt from the first compiler; --png writes the dumped frames as PNG files for review;
 * --sanitize adds a build of the first compiler with AddressSanitizer and UndefinedBehaviorSanitizer, whose frames
 * must match too.
 */
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { CXX, editorTree, loadArchive, must, ROOT, run, RUNTIME_INCLUDE } from '../common.mjs'
import { writePngs } from '../png.mjs'

const HERE = dirname(fileURLToPath(import.meta.url))
const CORE_SOURCES = ['hmi_core.c', 'hmi_theme.c', 'hmi_math.c', 'hmi_raster.c', 'hmi_text.c']
const CFLAGS = ['-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-ffp-contract=off']
/* STruC++ output builds with the flags product builds use; the C core keeps its warning gate. */
const CXXFLAGS = ['-std=gnu++17', '-O2', '-ffp-contract=off']
const SANITIZE = ['-O1', '-g', '-fsanitize=address,undefined', '-fno-sanitize-recover=all', '-fno-omit-frame-pointer']
const GOLDEN = join(HERE, 'golden.txt')

/* Flags of a target: the sanitized one trades -O2 for AddressSanitizer and UndefinedBehaviorSanitizer. */
const withSanitizer = (flags, sanitize) => (sanitize ? [...flags.filter((f) => f !== '-O2'), ...SANITIZE] : flags)

function parseArgs(argv) {
  const opts = { cc: ['cc'], update: false, png: null, sanitize: false }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--cc') opts.cc = argv[++i].split(/\s+/).filter(Boolean)
    else if (a === '--update') opts.update = true
    else if (a === '--sanitize') opts.sanitize = true
    else if (a === '--png') opts.png = argv[++i]
    else throw new Error(`unknown argument ${a}`)
  }
  return opts
}

/* The screens through STruC++ against the archive, the way the HMI build compiles them. */
async function generate(work, tree) {
  const { strucpp, archive } = await loadArchive('standard-widgets')
  const unit = strucpp.compile(readFileSync(join(HERE, 'screens.st'), 'utf8'), {
    libraries: [archive],
    headerFileName: 'hmi_unit.hpp',
  })
  if (unit.errors.length > 0)
    throw new Error(`screens: ${unit.errors.map((e) => `${e.line}: ${e.message}`).join('\n')}`)
  writeFileSync(join(work, 'hmi_unit.hpp'), unit.headerCode)
  writeFileSync(join(work, 'hmi_unit.cpp'), unit.cppCode)
  const fonts = join(work, 'fonts.c')
  must(
    run('npx', ['tsx', join(ROOT, 'tests', 'native', 'font-table.ts'), tree, fonts, 'all', 'compact'], { cwd: ROOT }),
    'font table',
  )
  return fonts
}

function build(cc, work, core, fonts, sanitize = false) {
  const name = `${basename(cc)}${sanitize ? '-sanitized' : ''}`
  const objects = []
  for (const src of [...CORE_SOURCES.map((s) => join(core, s)), fonts]) {
    const obj = join(work, `${name}_${basename(src, '.c')}.o`)
    must(run(cc, [...withSanitizer(CFLAGS, sanitize), `-I${core}`, '-c', src, '-o', obj]), `${cc} ${basename(src)}`)
    objects.push(obj)
  }
  const cxx = CXX[basename(cc)] ?? cc
  const out = join(work, `driver_${name}`)
  const r = run(cxx, [
    ...withSanitizer(CXXFLAGS, sanitize),
    `-I${RUNTIME_INCLUDE}`,
    `-I${core}`,
    `-I${work}`,
    join(HERE, 'driver.cpp'),
    join(work, 'hmi_unit.cpp'),
    ...objects,
    '-lm',
    '-o',
    out,
  ])
  must(r, `${cxx} driver`)
  return { name, out }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2))
  const tree = editorTree()
  const core = join(tree, 'resources', 'sources', 'hmi', 'core')
  const work = mkdtempSync(join(tmpdir(), 'hmi-lib-'))
  let failed = false
  const fail = (msg) => {
    console.error(`FAIL ${msg}`)
    failed = true
  }
  try {
    const fonts = await generate(work, tree)
    let reference = null
    const targets = [
      ...opts.cc.map((cc) => ({ cc, sanitize: false })),
      ...(opts.sanitize ? [{ cc: opts.cc[0], sanitize: true }] : []),
    ]
    for (const { cc, sanitize } of targets) {
      const target = build(cc, work, core, fonts, sanitize)
      const dump = opts.png && reference === null ? join(work, 'dump') : null
      if (dump) mkdirSync(dump, { recursive: true })
      const r = run(target.out, dump ? [dump] : [])
      if (r.status !== 0) {
        fail(`${target.name} driver:\n${r.stderr}${r.stdout}`)
        continue
      }
      if (dump) writePngs(dump, opts.png)
      reference ??= r.stdout
      if (r.stdout !== reference) fail(`${target.name} frames differ from ${opts.cc[0]}`)
      else console.log(`${target.name}: ${r.stdout.trim().split('\n').length} lines`)
    }
    if (reference !== null) {
      if (opts.update) {
        writeFileSync(GOLDEN, reference)
        console.log('golden.txt updated')
      } else if (reference !== readFileSync(GOLDEN, 'utf8')) {
        fail(`frames differ from golden.txt:\n${reference}`)
      } else {
        console.log('frames match golden.txt')
      }
    }
  } finally {
    rmSync(work, { recursive: true, force: true })
  }
  if (failed) process.exit(1)
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
