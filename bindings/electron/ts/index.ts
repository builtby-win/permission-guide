import path from 'node:path';

export type Kind = 'accessibility' | 'screen-recording' | 'input-monitoring';

export interface PresentOptions {
  /** Path of the .app the user should drag into the list. Defaults to the main bundle
   *  (in Electron: the Electron/app bundle). */
  appPath?: string;
  /** Display name shown in the guide. Defaults to the bundle name. */
  appName?: string;
}

interface Native {
  status(kind: number): boolean;
  present(kind: number, appPath: string | null, appName: string | null): Promise<boolean>;
  dismiss(): void;
}

const KINDS: Record<Kind, number> = { accessibility: 0, 'screen-recording': 1, 'input-monitoring': 2 };

let native: Native | undefined;
function load(): Native {
  if (process.platform !== 'darwin') {
    throw new Error('@builtby/permission-guide is only supported on macOS');
  }
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  native ??= require('node-gyp-build')(path.join(__dirname, '..')) as Native;
  return native;
}

function kindId(kind: Kind): number {
  const id = KINDS[kind];
  if (id === undefined) throw new TypeError(`unknown permission kind: ${String(kind)}`);
  return id;
}

/** True if the permission is currently granted to this process. Accessibility is cached
 *  per-process by macOS: a freshly granted permission may need an app restart to show up. */
export function status(kind: Kind): boolean {
  return load().status(kindId(kind));
}

/** Shows the docked guide beside System Settings. Resolves true when the permission is
 *  granted, false when the guide is dismissed. Needs the AppKit main loop (Electron main process). */
export function present(kind: Kind, options: PresentOptions = {}): Promise<boolean> {
  return load().present(kindId(kind), options.appPath ?? null, options.appName ?? null);
}

/** Closes the guide; a pending present() promise resolves false. */
export function dismiss(): void {
  load().dismiss();
}
