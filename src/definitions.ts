import type { PluginListenerHandle } from '@capacitor/core';

export interface UnzipOptions {
  /**
   * The archive to extract: an absolute path or a `file://` URL.
   */
  source: string;
  /**
   * The directory to extract into: an absolute path or a `file://` URL.
   * It is created when it does not exist.
   */
  destination: string;
  /**
   * Replace files that already exist in the destination.
   *
   * @default true
   */
  overwrite?: boolean;
}

export interface UnzipResult {
  /**
   * How many entries (files and directories) were extracted.
   */
  entries: number;
}

export interface UnzipProgress {
  /**
   * The `destination` of the call this event belongs to, exactly as it was passed.
   */
  destination: string;
  /**
   * Entries extracted so far.
   */
  loaded: number;
  /**
   * Entries in the archive.
   */
  total: number;
}

/**
 * Why a call failed, as the `code` of the rejected error.
 *
 * - `INVALID_ARGUMENT`: `source` or `destination` is missing, relative or not a file URL
 * - `NOT_FOUND`: there is no file at `source`
 * - `BAD_ARCHIVE`: `source` is not a zip archive, is empty, or one of its entries is corrupt
 * - `UNSAFE_ENTRY`: an entry would land outside `destination` (`../` or an absolute path); nothing is extracted
 * - `EXISTS`: a file is already there and `overwrite` is `false`
 * - `IO`: the destination could not be written
 */
export type UnzipErrorCode = 'INVALID_ARGUMENT' | 'NOT_FOUND' | 'BAD_ARCHIVE' | 'UNSAFE_ENTRY' | 'EXISTS' | 'IO';

export interface ZipPlugin {
  /**
   * Extract a zip archive into a directory.
   *
   * Every entry is checked before anything is written, so an archive with an entry that would escape
   * `destination` is refused whole, with `UNSAFE_ENTRY`.
   */
  unzip(options: UnzipOptions): Promise<UnzipResult>;

  /**
   * Listen to the progress of every `unzip` call: one event per extracted entry.
   * Filter on `destination` when more than one call runs at once.
   */
  addListener(eventName: 'progress', listenerFunc: (progress: UnzipProgress) => void): Promise<PluginListenerHandle>;

  /**
   * Remove every listener of this plugin.
   */
  removeAllListeners(): Promise<void>;
}
