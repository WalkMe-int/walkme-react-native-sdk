# Example apps

Two runnable apps, one per React Native architecture. They share the same
`App.tsx` and the same public API calls — the only differences are the React
Native version and the architecture flag, which is what makes them useful as a
pair.

| App | React Native | Architecture | Android package | iOS scheme |
|---|---|---|---|---|
| [`new-arch`](new-arch) | 0.85.3 | New (bridgeless, TurboModules) | `com.walkmeexample` | `WalkMeExample` |
| [`legacy`](legacy) | 0.81.4 | Legacy (`NativeModules`) | `com.walkmeexamplelegacy` | `WalkMeExampleLegacy` |

Both depend on the bridge as `file:../..` — a link to this checkout — so they
run the sources on your current branch, with no packing or publishing step in
between. Each app's README covers prerequisites, running, and building APKs.

```sh
cd new-arch     # or: cd legacy
npm install
npm start
npm run android
```
