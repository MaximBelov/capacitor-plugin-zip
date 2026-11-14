import type { UnzipOptions, UnzipProgress, UnzipResult, ZipPlugin } from './definitions';

/**
 * `unzip` with a progress callback that hears only this call: it listens for the call's own `destination`,
 * and stops listening when the call settles, whether it resolved or rejected.
 */
export async function unzipWithProgress(
  plugin: Pick<ZipPlugin, 'unzip' | 'addListener'>,
  options: UnzipOptions,
  onProgress: (progress: UnzipProgress) => void,
): Promise<UnzipResult> {
  const handle = await plugin.addListener('progress', (progress) => {
    if (progress.destination === options.destination) {
      onProgress(progress);
    }
  });
  try {
    return await plugin.unzip(options);
  } finally {
    await handle.remove();
  }
}
