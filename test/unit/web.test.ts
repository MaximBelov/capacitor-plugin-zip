import { describe, expect, it } from 'vitest';

import { ZipWeb } from '../../src/web';

describe('the web implementation', () => {
  it('rejects unzip as unimplemented', async () => {
    await expect(new ZipWeb().unzip({ source: '/a.zip', destination: '/out' })).rejects.toMatchObject({
      code: 'UNIMPLEMENTED',
    });
  });
});
