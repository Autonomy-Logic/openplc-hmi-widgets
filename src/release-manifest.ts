// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * The release manifest (`openplc-hmi-widgets.json`) and the metadata each archive carries under its top-level
 * `openplc` key. Both formats are versioned; consumers refuse a format version they do not know.
 */
import type { HmiWidgetCatalog } from './catalog-types.js'

/** Format version of the release manifest. */
export const RELEASE_MANIFEST_FORMAT = 1

/** Format version of the `openplc` metadata inside an archive. */
export const ARCHIVE_METADATA_FORMAT = 1

/** File name of the release manifest among the release assets. */
export const RELEASE_MANIFEST_FILE = 'openplc-hmi-widgets.json'

/** File name of the SHA-256 sums among the release assets. */
export const SHA256SUMS_FILE = 'SHA256SUMS'

/** SPDX expression of every archive: the GPLv3, or Autonomy Logic's commercial licence (see LICENSING.md). */
export const LIBRARY_LICENSE = 'GPL-3.0-only OR LicenseRef-Autonomy-Commercial'

/** `hmi`: a widget library the HMI designer and build use. `plc`: a library the PLC program uses. */
export type LibraryKind = 'hmi' | 'plc'

/** What a PLC-side archive carries under `openplc`. */
export interface PlcArchiveMetadata {
  formatVersion: typeof ARCHIVE_METADATA_FORMAT
  kind: 'plc'
  license: string
}

/** What a widget archive carries under `openplc`. */
export interface HmiArchiveMetadata {
  formatVersion: typeof ARCHIVE_METADATA_FORMAT
  kind: 'hmi'
  license: string
  /** API version of the HMI C core the archive's code calls. */
  hmiCoreApi: number
  catalog: HmiWidgetCatalog
}

export type ArchiveMetadata = PlcArchiveMetadata | HmiArchiveMetadata

interface ReleaseArchiveBase {
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

export interface ReleasePlcArchive extends ReleaseArchiveBase {
  kind: 'plc'
}

export interface ReleaseHmiArchive extends ReleaseArchiveBase {
  kind: 'hmi'
  hmiCoreApi: number
  catalog: HmiWidgetCatalog
}

export type ReleaseArchive = ReleasePlcArchive | ReleaseHmiArchive

export interface ReleaseManifest {
  formatVersion: typeof RELEASE_MANIFEST_FORMAT
  name: 'openplc-hmi-widgets'
  /** Release version, without the `v` of its tag. */
  version: string
  strucppVersion: string
  archives: ReleaseArchive[]
}
