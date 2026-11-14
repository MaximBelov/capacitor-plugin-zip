import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// The methods of definitions.ts, the native methods of each platform and the README have to agree: a method that one
// platform lacks rejects there with "not implemented", which no unit test on the other platform would notice.
const root = join(__dirname, '..', '..');
const read = (file: string) => readFileSync(join(root, file), 'utf8');

const listenerMethods = new Set(['addListener', 'removeAllListeners']);

function declared(): string[] {
  const source = read('src/definitions.ts');
  const body = /export interface ZipPlugin \{([\s\S]*?)\n\}/.exec(source)?.[1] ?? '';
  return [...body.matchAll(/^\s{2}(\w+)\(/gm)].map((m) => m[1]).filter((name) => !listenerMethods.has(name));
}

describe('platform parity', () => {
  const methods = declared();

  it('finds the methods', () => {
    expect(methods).toEqual(['unzip']);
  });

  it.each(methods)('%s is a method on iOS', (method) => {
    expect(read('ios/Sources/ZipPlugin/ZipPlugin.swift')).toContain(`CAPPluginMethod(name: "${method}"`);
  });

  it.each(methods)('%s is a method on Android', (method) => {
    expect(read('android/src/main/kotlin/io/github/maximbelov/capacitor/zip/ZipPlugin.kt')).toMatch(
      new RegExp(`@PluginMethod\\s+fun ${method}\\(`),
    );
  });

  it.each(methods)('%s is in the README', (method) => {
    expect(read('README.md')).toContain(`### ${method}(`);
  });

  it('the error codes are the same on every platform', () => {
    const codes = [...read('src/definitions.ts').matchAll(/'([A-Z_]+)'/g)].map((m) => m[1]).sort();
    const used = (file: string) => new Set([...read(file).matchAll(/"([A-Z][A-Z_]+)"/g)].map((m) => m[1]));
    const ios = used('ios/Sources/ZipPlugin/Unzipper.swift');
    const android = used('android/src/main/kotlin/io/github/maximbelov/capacitor/zip/Unzipper.kt');
    for (const code of codes) {
      expect(ios, `iOS uses ${code}`).toContain(code);
      expect(android, `Android uses ${code}`).toContain(code);
    }
  });
});
