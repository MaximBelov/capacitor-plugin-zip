import { registerPlugin } from '@capacitor/core';

import type { UnzipOptions, UnzipProgress, UnzipResult, ZipPlugin } from './definitions';
import { unzipWithProgress } from './with-progress';

const Zip = registerPlugin<ZipPlugin>('Zip', {
  web: () => import('./web').then((m) => new m.ZipWeb()),
});

/**
 * Extract `options.source` into `options.destination`, calling `onProgress` once per extracted entry.
 */
function unzip(options: UnzipOptions, onProgress?: (progress: UnzipProgress) => void): Promise<UnzipResult> {
  return onProgress ? unzipWithProgress(Zip, options, onProgress) : Zip.unzip(options);
}

export * from './definitions';
export { Zip, unzip };
