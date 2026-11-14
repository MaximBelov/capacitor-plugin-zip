# capacitor-plugin-zip

Extract zip archives in a Capacitor app, on iOS and Android.

## Why

[`cordova-plugin-zip`](https://github.com/MobileChromeApps/cordova-plugin-zip) has done this job for Cordova apps for years, but it has not
been updated for a long time, it ships its own copy of minizip, and it does not run in a Capacitor app. This plugin does the same job
the Capacitor way: one call that returns a promise, progress as plugin events, and the platforms' own zip support underneath
([ZIPFoundation](https://github.com/weichsel/ZIPFoundation) on iOS, `java.util.zip` on Android).

It is also stricter than the plugin it replaces. Every entry is checked before anything is written, and an archive with an entry that
would land outside the destination (`../something`, or an absolute path, the "zip slip" attack) is refused whole.

## Install

```bash
npm install capacitor-plugin-zip
npx cap sync
```

Requirements: Capacitor 8, iOS 15 or later (Swift Package Manager or CocoaPods), Android API 26 or later.

## Usage

```ts
import { unzip } from 'capacitor-plugin-zip';

const { entries } = await unzip(
  { source: '/path/to/bundle.zip', destination: '/path/to/bundle' },
  ({ loaded, total }) => console.log(`${loaded} of ${total}`),
);
```

`source` and `destination` are absolute paths or `file://` URLs, for example a `uri` from `@capacitor/filesystem`. The destination is
created when it is missing, and files already in it are replaced unless you pass `overwrite: false`.

The `unzip` helper listens for the progress of its own call and stops listening when the call settles. The plugin object is exported
too, as `Zip`, if you prefer to handle the listener yourself:

```ts
import { Zip } from 'capacitor-plugin-zip';

const handle = await Zip.addListener('progress', ({ destination, loaded, total }) => { /* ... */ });
try {
  await Zip.unzip({ source, destination });
} finally {
  await handle.remove();
}
```

A failed call rejects with an error whose `code` (exported as the type `UnzipErrorCode`) says why:

| Code | Meaning |
| --- | --- |
| `INVALID_ARGUMENT` | `source` or `destination` is missing, relative, or a URL that is not `file://` |
| `NOT_FOUND` | there is no file at `source` |
| `BAD_ARCHIVE` | `source` is not a zip archive, is empty, or has a corrupt entry |
| `UNSAFE_ENTRY` | an entry would land outside `destination`; nothing was extracted |
| `EXISTS` | a file is already there and `overwrite` is `false`; the entries before it were extracted |
| `IO` | the destination could not be written |

### Coming from cordova-plugin-zip

| cordova-plugin-zip | capacitor-plugin-zip |
| --- | --- |
| `zip.unzip(source, destination, callback, progressCallback)` | `unzip({ source, destination }, onProgress)` |
| `callback(0)` on success, `callback(-1)` on failure | the promise resolves, or rejects with a `code` |
| progress `{ loaded, total }`: bytes on Android, entries on iOS | progress `{ loaded, total }`: entries on both |
| `cdvfile://` URLs | absolute paths and `file://` URLs |
| CRX archives (a Chrome extension header before the zip) | not supported |

## Platforms

| | iOS | Android | Web |
| --- | --- | --- | --- |
| `unzip` | yes | yes | rejects with `UNIMPLEMENTED` |

Symbolic links inside an archive are restored on iOS when they point inside the destination (ZIPFoundation refuses the others), and
written as plain files on Android, where `java.util.zip` does not know about links.

## API

<docgen-index>

* [`unzip(...)`](#unzip)
* [`addListener('progress', ...)`](#addlistenerprogress-)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### unzip(...)

```typescript
unzip(options: UnzipOptions) => Promise<UnzipResult>
```

Extract a zip archive into a directory.

Every entry is checked before anything is written, so an archive with an entry that would escape
`destination` is refused whole, with `UNSAFE_ENTRY`.

| Param         | Type                                                  |
| ------------- | ----------------------------------------------------- |
| **`options`** | <code><a href="#unzipoptions">UnzipOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#unzipresult">UnzipResult</a>&gt;</code>

--------------------


### addListener('progress', ...)

```typescript
addListener(eventName: 'progress', listenerFunc: (progress: UnzipProgress) => void) => Promise<PluginListenerHandle>
```

Listen to the progress of every `unzip` call: one event per extracted entry.
Filter on `destination` when more than one call runs at once.

| Param              | Type                                                                           |
| ------------------ | ------------------------------------------------------------------------------ |
| **`eventName`**    | <code>'progress'</code>                                                        |
| **`listenerFunc`** | <code>(progress: <a href="#unzipprogress">UnzipProgress</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

Remove every listener of this plugin.

--------------------


### Interfaces


#### UnzipResult

| Prop          | Type                | Description                                              |
| ------------- | ------------------- | -------------------------------------------------------- |
| **`entries`** | <code>number</code> | How many entries (files and directories) were extracted. |


#### UnzipOptions

| Prop              | Type                 | Description                                                                                               | Default           |
| ----------------- | -------------------- | --------------------------------------------------------------------------------------------------------- | ----------------- |
| **`source`**      | <code>string</code>  | The archive to extract: an absolute path or a `file://` URL.                                              |                   |
| **`destination`** | <code>string</code>  | The directory to extract into: an absolute path or a `file://` URL. It is created when it does not exist. |                   |
| **`overwrite`**   | <code>boolean</code> | Replace files that already exist in the destination.                                                      | <code>true</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### UnzipProgress

| Prop              | Type                | Description                                                                    |
| ----------------- | ------------------- | ------------------------------------------------------------------------------ |
| **`destination`** | <code>string</code> | The `destination` of the call this event belongs to, exactly as it was passed. |
| **`loaded`**      | <code>number</code> | Entries extracted so far.                                                      |
| **`total`**       | <code>number</code> | Entries in the archive.                                                        |

</docgen-api>

## Development

```bash
npm install
npm run build           # TypeScript, the bundle and the API section of this README
npm test                # TypeScript unit tests (Vitest)
npm run test:android    # the Kotlin on the JVM (JUnit), needs JDK 21 and the Android SDK
npm run test:ios        # the Swift with XCTest on an iOS simulator, needs Xcode 26
npm run verify          # builds every platform the way an app would
```

The test archives are in `test/fixtures`, shared by the Android and iOS tests: `basic.zip` (files, nested folders, an empty folder),
`slip.zip` and `absolute.zip` (entries that try to leave the destination) and `not-a-zip.zip`.

## Licence

MIT
