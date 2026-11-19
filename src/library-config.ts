// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * A library's `library.json`: STruC++'s library identity (`name`, `displayName`, `version`, `namespace`,
 * `description`) plus the archive's kind, the headers its code includes, its sources in compile order and the libraries
 * of this repository it depends on.
 */
import type { LibraryKind } from './release-manifest.js'

export interface LibraryConfig {
  name: string
  displayName: string
  version: string
  namespace: string
  description: string
  kind: LibraryKind
  headers: string[]
  /** `.st` files of the library's folder, in the order they are compiled. */
  sources: string[]
  /** Names of libraries of this repository it is compiled against. */
  dependencies: string[]
}

const NAME = /^[a-z][a-z0-9-]*$/
const NAMESPACE = /^[a-z_][a-z0-9_]*$/
const SOURCE = /^[A-Za-z0-9_-]+\.st$/

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function stringList(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string')
}

/** Parses and checks a `library.json`; `label` names it in errors. */
export function parseLibraryConfig(text: string, label: string): LibraryConfig {
  const raw: unknown = JSON.parse(text)
  const fail = (message: string): never => {
    throw new Error(`${label}: ${message}`)
  }
  if (!isRecord(raw)) return fail('must be a JSON object')
  const text_ = (key: string): string => {
    const value = raw[key]
    return typeof value === 'string' && value.length > 0 ? value : fail(`"${key}" must be a non-empty string`)
  }
  const name = text_('name')
  if (!NAME.test(name)) fail(`"name" must be kebab-case: ${name}`)
  const namespace = text_('namespace')
  if (!NAMESPACE.test(namespace)) fail(`"namespace" must be a C++ identifier in lower case: ${namespace}`)
  const kind = raw.kind
  if (kind !== 'hmi' && kind !== 'plc') return fail('"kind" must be "hmi" or "plc"')
  const headers = raw.headers ?? []
  if (!stringList(headers)) return fail('"headers" must be a list of file names')
  const sources = raw.sources
  if (!stringList(sources) || sources.length === 0) return fail('"sources" must list the .st files')
  for (const s of sources) if (!SOURCE.test(s)) fail(`source "${s}" must be a .st file name`)
  if (new Set(sources).size !== sources.length) fail('"sources" lists a file twice')
  const dependencies = raw.dependencies ?? []
  if (!stringList(dependencies)) return fail('"dependencies" must be a list of library names')
  return {
    name,
    displayName: text_('displayName'),
    version: text_('version'),
    namespace,
    description: text_('description'),
    kind,
    headers,
    sources,
    dependencies,
  }
}
