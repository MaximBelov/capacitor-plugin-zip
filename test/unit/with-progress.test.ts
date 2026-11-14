import type { PluginListenerHandle } from '@capacitor/core';
import { describe, expect, it, vi } from 'vitest';

import type { UnzipOptions, UnzipProgress, UnzipResult } from '../../src/definitions';
import { unzipWithProgress } from '../../src/with-progress';

function fakePlugin(run: (emit: (p: UnzipProgress) => void, options: UnzipOptions) => Promise<UnzipResult>) {
  const listeners = new Set<(p: UnzipProgress) => void>();
  const remove = vi.fn(async () => undefined);
  const plugin = {
    addListener: vi.fn(async (_event: 'progress', fn: (p: UnzipProgress) => void): Promise<PluginListenerHandle> => {
      listeners.add(fn);
      return {
        remove: async () => {
          listeners.delete(fn);
          await remove();
        },
      };
    }),
    unzip: (options: UnzipOptions) => run((p) => listeners.forEach((fn) => fn(p)), options),
  };
  return { plugin, listeners, remove };
}

describe('unzipWithProgress', () => {
  it('passes on only the events of its own destination, and stops listening when done', async () => {
    const { plugin, listeners, remove } = fakePlugin(async (emit, options) => {
      emit({ destination: '/other', loaded: 1, total: 9 });
      emit({ destination: options.destination, loaded: 1, total: 2 });
      emit({ destination: options.destination, loaded: 2, total: 2 });
      return { entries: 2 };
    });
    const seen: UnzipProgress[] = [];

    const result = await unzipWithProgress(plugin, { source: '/a.zip', destination: '/out' }, (p) => seen.push(p));

    expect(result).toEqual({ entries: 2 });
    expect(seen).toEqual([
      { destination: '/out', loaded: 1, total: 2 },
      { destination: '/out', loaded: 2, total: 2 },
    ]);
    expect(remove).toHaveBeenCalledOnce();
    expect(listeners.size).toBe(0);
  });

  it('stops listening when the call rejects, and passes the rejection on', async () => {
    const failure = Object.assign(new Error('unsafe'), { code: 'UNSAFE_ENTRY' });
    const { plugin, listeners } = fakePlugin(async () => {
      throw failure;
    });

    await expect(unzipWithProgress(plugin, { source: '/a.zip', destination: '/out' }, () => undefined)).rejects.toBe(
      failure,
    );
    expect(listeners.size).toBe(0);
  });
});
