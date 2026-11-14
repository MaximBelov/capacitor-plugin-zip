import { WebPlugin } from '@capacitor/core';

import type { UnzipOptions, UnzipResult, ZipPlugin } from './definitions';

export class ZipWeb extends WebPlugin implements ZipPlugin {
  async unzip(options: UnzipOptions): Promise<UnzipResult> {
    throw this.unimplemented(`Cannot unzip ${options.source} on the web: it needs the native file system.`);
  }
}
