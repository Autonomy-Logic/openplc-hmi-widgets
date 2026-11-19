// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Autonomy®
/**
 * The widget catalogue a widget library carries for the OpenPLC Editor's HMI designer: the palette, the inspector and
 * the HMI build read it instead of the library's source. Field names and meanings are a contract with the editor.
 */

export type HmiPropertyGroup = 'data' | 'display' | 'layout'

export type HmiPropertyKind = 'bool' | 'number' | 'string' | 'color' | 'enum' | 'elementRef' | 'other'

export interface HmiWidgetProperty {
  /** Name as written. */
  name: string
  /** Declared type, as written for library types. */
  type: string
  kind: HmiPropertyKind
  group: HmiPropertyGroup
  /** Default value as ST text: the widget type's own (`typeDefaults`) when it sets one, else the declared one. */
  defaultValue?: string
  /** BOOL property that must be TRUE for this one to take effect. */
  enabledBy?: string
  /** Value as ST text that previews and palette thumbnails give the property, from `hmi_preview`. */
  previewValue?: string
  /** Length of a STRING(n) property. */
  maxLength?: number
  /** Members of an enumerated property, as written. */
  enumMembers?: string[]
  /** Block that declares the property. */
  declaredBy: string
}

export interface HmiWidgetOutput {
  name: string
  type: string
}

export interface HmiWidgetBinding {
  name: string
  direction: 'input' | 'output'
  type: string
}

/** A widget input whose literal value names PLC data, and the kind of data it takes. */
export interface HmiWidgetSource {
  name: string
  /** What it takes, as its `hmi_source` attribute says, upper case with single spaces. */
  type: string
  /** Its position among the widget's sources. */
  slot: number
}

/** Inputs marked `hmi_series`, in declaration order. */
export interface HmiWidgetSeries {
  count: string
  values: string[]
  colors: string[]
}

export interface HmiWidgetInfo {
  /** Name as written. */
  name: string
  /** Name of the library that declares it. */
  library: string
  /** Base block, as written. */
  extends: string
  /** Palette group (`hmi_palette`). */
  palette?: string
  /** Inputs, the base block's first. */
  properties: HmiWidgetProperty[]
  outputs: HmiWidgetOutput[]
  /** What a variable dropped on the widget is wired to (`hmi_main`). */
  main?: HmiWidgetBinding
  /** A main input with `Changed` and `NewValue` outputs. */
  twoWay?: { value: string; changed: string; newValue: string; range?: string; maxLength?: string }
  /** A main BOOL output with a `Changed` output. */
  momentary?: { value: string; changed: string }
  /** Other BOOL outputs. */
  events: string[]
  series?: HmiWidgetSeries
  /** Inherited inputs the type starts with another value (`hmi_default`). */
  typeDefaults?: Array<{ name: string; value: string }>
  /** Target capability the widget needs (`hmi_requires`). */
  requires?: string
  /** STRING inputs naming PLC data (`hmi_source`), in declaration order. */
  sources?: HmiWidgetSource[]
}

/** The catalogue of one widget library. */
export interface HmiWidgetCatalog {
  /** Widgets in declaration order. */
  widgets: HmiWidgetInfo[]
  /** Fields of the library's COLOR constant, as written; empty when it declares none. */
  colors: string[]
}
