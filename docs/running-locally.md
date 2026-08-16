# Running Shadow on your machine

Development happens on Windows. That has two consequences worth stating up
front: **iOS can only be built in CI**, and until a JDK is installed, Android
cannot be built at all.

Android is the practical local target. Identity, the browser, autofill, the
wallet and all five local-storage flows work there. Only tracker blocking is
iOS-only, and CI already proves that compiles.

---

## What is already in place

Better than you might expect:

- The Android SDK is installed and its licences are accepted, at
  `%LOCALAPPDATA%\Android\sdk` — platforms 34/35/36, build-tools,
  platform-tools, the emulator, and two x86_64 system images.
- `android/local.properties` exists and points at the right SDK and Flutter.
- Signing is not a blocker. The release build type reuses the debug config and
  `~/.android/debug.keystore` already exists.
- `ndkVersion` is pinned to `27.1.12297006`, which you have. Flutter would
  otherwise ask for `28.2.13676358` and trigger a ~1 GB download.
- The Gradle heap is set to 4 GB. The Flutter template ships 8 GB plus 4 GB
  metaspace, which on this 16 GB machine leaves nothing for an emulator.

## The one hard blocker: there is no JDK

No `JAVA_HOME`, no `java` on `PATH`, no Android Studio, no Gradle-provisioned
toolchain. This is why `flutter build apk` fails, and it also blocks
`sdkmanager` and `avdmanager`, which are themselves Java programs.

**Simplest fix:** install Android Studio. It bundles a JDK (JBR 21) and gives
you the AVD manager in the same move.

**Leaner fix:** install a standalone JDK 17 or 21 — AGP 8.11 requires 17 or
above — then point Flutter at it:

```bash
flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-21"
```

Verify with `flutter doctor -v`. It will also confirm the SDK and emulator
state in one pass.

## Create an emulator

You have system images downloaded but no AVD defined. After the JDK is in
place:

```bash
avdmanager create avd -n shadow -k "system-images;android-36;google_apis_playstore;x86_64" -d pixel_7
```

Emulator performance depends on hardware acceleration (WHPX or the Android
Emulator Hypervisor Driver). Without it an x86_64 image is unusably slow.

## Run it

```bash
flutter run
```

The first build downloads Gradle 8.14 plus the AGP, Kotlin and androidx graph —
several hundred megabytes, once.

## Pointing the app at a local backend

Two things will otherwise make a perfectly good build look broken:

**`localhost` on an emulator is the emulator.** The machine running your server
is `10.0.2.2`. Set it either at build time:

```bash
flutter run --dart-define=SHADOW_API_URL=http://10.0.2.2:8080/api
```

or at run time in **Settings → Advanced → Shadow API address**.

**Cleartext HTTP is blocked** from targetSdk 28 onward, and that default is
correct for this app. Debug builds carry a narrow exception for loopback
addresses only (`android/app/src/debug/res/xml/network_security_config.xml`),
so a local http backend works while release builds stay strict. Do not widen
it — the WebView obeys the same policy, and a privacy browser silently loading
plaintext pages is the thing that config exists to prevent.

Note that the Rust backend does not currently start. It parses two invalid
program IDs during startup and exits, so there is nothing to point at yet.
Everything that matters locally — identity, browsing, autofill, bookmarks,
history, downloads, extensions, activity, and token balances over RPC — works
without it.

## What CI covers

| Job | Runner | What it proves |
| --- | --- | --- |
| Mobile | ubuntu | `flutter analyze` is clean and the tests pass |
| Android | ubuntu | the Gradle path compiles to a debug APK |
| iOS | macOS | the Xcode project and CocoaPods graph build, unsigned |
| Backend | ubuntu | the Rust crate compiles |

`flutter analyze` must print **No issues found!** and exit 0. Counting error
and warning lines is not enough — info-level lints fail the build, which has
caught this project out before.

The iOS job uploads `Runner.app` as an artifact. It is unsigned, so it cannot
be installed on a device without re-signing; it is there for inspection.
