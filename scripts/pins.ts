// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/** The repository root and the STruC++ pin of `binary-versions.json`. */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

export interface ToolPin {
  version: string
  repository: string
  /** SHA-256 of the release tarball, lower-case hex. */
  sha256: string
}

/** The STruC++ release the archives are built with. */
export function pinnedStrucpp(): ToolPin {
  const raw: unknown = JSON.parse(readFileSync(join(ROOT, 'binary-versions.json'), 'utf8'))
  if (typeof raw !== 'object' || raw === null || !('strucpp' in raw))
    throw new Error('binary-versions.json has no strucpp')
  const pin = raw.strucpp
  if (
    typeof pin !== 'object' ||
    pin === null ||
    !('version' in pin) ||
    !('repository' in pin) ||
    !('sha256' in pin) ||
    typeof pin.version !== 'string' ||
    typeof pin.repository !== 'string' ||
    typeof pin.sha256 !== 'string' ||
    !/^[0-9a-f]{64}$/.test(pin.sha256)
  )
    throw new Error('binary-versions.json: strucpp needs a version, a repository and the sha256 of its tarball')
  return { version: pin.version, repository: pin.repository, sha256: pin.sha256 }
}
