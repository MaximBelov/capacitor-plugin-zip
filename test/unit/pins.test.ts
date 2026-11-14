import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { SDKS, assess, bump, compareVersions, decide, readPin, versionOf } from '../../scripts/check-pins.mjs';

const root = join(__dirname, '..', '..');
const read = (file: string) => readFileSync(join(root, file), 'utf8');
const [zipFoundation] = SDKS;

describe('the ZIPFoundation pin', () => {
  it('is read from Package.swift, and the podspec names the same version', () => {
    const pinned = readPin(zipFoundation);
    expect(pinned).toMatch(/^\d+\.\d+\.\d+$/);
    expect(zipFoundation.followers[0].pin.exec(read('CapacitorPluginZip.podspec'))?.[1]).toBe(pinned);
  });

  it('compares versions as numbers', () => {
    expect(compareVersions('0.9.9', '0.9.20')).toBeLessThan(0);
    expect(compareVersions('0.9.20', '0.9.20')).toBe(0);
    expect(compareVersions('1.0.0', '0.9.20')).toBeGreaterThan(0);
  });

  it('refuses a tag that is not three numbers', () => {
    expect(versionOf('v1.2.3')).toBe('1.2.3');
    expect(() => versionOf('1.2.3-beta')).toThrow();
  });

  it('moves the pin in both files, and only there', () => {
    const files: Record<string, string> = {};
    const written = bump(zipFoundation, readPin(zipFoundation), '1.0.0', {
      read,
      write: (file: string, text: string) => (files[file] = text),
    });
    expect(written).toEqual(['Package.swift', 'CapacitorPluginZip.podspec']);
    expect(files['Package.swift']).toContain('ZIPFoundation.git", exact: "1.0.0"');
    expect(files['CapacitorPluginZip.podspec']).toContain("'ZIPFoundation', '1.0.0'");
  });

  it('opens a pull request only when behind and not already proposed', () => {
    const behind = assess(zipFoundation, '0.9.20', '1.0.0');
    expect(behind.major).toBe(true);
    expect(decide(behind, []).open).toBe(true);
    expect(decide(behind, [{ number: 3, title: behind.title, state: 'CLOSED', headRefName: behind.branch }]).open).toBe(
      false,
    );
    expect(decide(assess(zipFoundation, '0.9.20', '0.9.20'), []).open).toBe(false);
  });
});
