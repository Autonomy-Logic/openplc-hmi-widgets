// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * The release assets: one plain STruC++ archive per library, the licence files, and `SHA256SUMS`, which lists every
 * other asset with its SHA-256 in `sha256sum` format. Consumers pin the SHA-256 of `SHA256SUMS`.
 */

/** File name of the SHA-256 sums among the release assets. */
export const SHA256SUMS_FILE = 'SHA256SUMS'

/** Licence files of the repository published with every release. */
export const LICENSE_FILES = ['LICENSE', 'LICENSING.md'] as const

/** One library archive of the release. */
export interface ReleaseArchive {
  name: string
  /** Archive file name among the release assets. */
  file: string
  sha256: string
}
