import { invoke } from '@tauri-apps/api/core'
import { listen, type UnlistenFn } from '@tauri-apps/api/event'

export type PermissionKind = 'accessibility' | 'screenRecording' | 'inputMonitoring'

export interface PresentOptions {
  /** Path of the .app to drag into the list. Default: the running app's bundle. */
  appPath?: string
  /** Display name. Default: derived from the bundle. */
  appName?: string
}

export interface PermissionResult {
  kind: PermissionKind
  granted: boolean
}

/** Whether the permission is currently granted. */
export function status(kind: PermissionKind): Promise<boolean> {
  return invoke<boolean>('plugin:permission-guide|status', { kind })
}

/** Opens the Privacy pane and docks the guide. Resolves once requested; listen with `onResult`. */
export function present(kind: PermissionKind, opts: PresentOptions = {}): Promise<void> {
  return invoke<void>('plugin:permission-guide|present', {
    kind,
    appPath: opts.appPath,
    appName: opts.appName,
  })
}

/** Closes the guide; a pending present resolves with `granted: false`. */
export function dismiss(): Promise<void> {
  return invoke<void>('plugin:permission-guide|dismiss')
}

/** Subscribe to guide outcomes. Returns the unlisten function. */
export function onResult(cb: (r: PermissionResult) => void): Promise<UnlistenFn> {
  return listen<PermissionResult>('permission-guide://result', (e) => cb(e.payload))
}
