// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * The release manifest (`openplc-hmi-widgets.json`). Its format is versioned; consumers refuse a format version they do
 * not know. The archives it lists are plain STruC++ archives.
 */

/** Format version of the release manifest. */
export const RELEASE_MANIFEST_FORMAT = 2

/** File name of the release manifest among the release assets. */
export const RELEASE_MANIFEST_FILE = 'openplc-hmi-widgets.json'

/** File name of the SHA-256 sums among the release assets. */
export const SHA256SUMS_FILE = 'SHA256SUMS'

/** SPDX expression of every archive: the GPLv3, or Autonomy Logic's commercial licence (see LICENSING.md). */
export const LIBRARY_LICENSE = 'GPL-3.0-only OR LicenseRef-Autonomy-Commercial'

export interface ReleaseArchive {
  name: string
  displayName: string
  version: string
  /** Archive file name among the release assets. */
  file: string
  sha256: string
  size: number
  /** STruC++ version the archive was compiled with. */
  strucppVersion: string
  /** Headers the archive's code includes; the consumer supplies them. */
  headers: string[]
  license: string
}

export interface ReleaseManifest {
  formatVersion: typeof RELEASE_MANIFEST_FORMAT
  name: 'openplc-hmi-widgets'
  /** Release version, without the `v` of its tag. */
  version: string
  strucppVersion: string
  archives: ReleaseArchive[]
}
