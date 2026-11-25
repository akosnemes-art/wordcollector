# Word Collector

Word Collector is an Android vocabulary notebook for Hungarian and English. It
keeps your collection on your device in the order you saved it.

## Install on Android

- **Manual download**. Open the [latest GitHub release](https://github.com/akosnemes-art/wordcollector/releases/latest), download the APK under **Assets**, then open it on Android.
- **Obtainium**. Tap **Add app**, paste `https://github.com/akosnemes-art/wordcollector`, and install the latest release from there.

## Use the app

- Add a word in either direction. Word Collector saves the highest-ranked
  translation directly. It looks up the submitted word and language through
  Wiktapi’s live Wiktionary API and uses its bundled dictionaries if the lookup
  is unavailable or has no matching entry.
- A new translation stays visible for five seconds. Rub the translation area
  to reveal it again, then hold the translation for two seconds to edit it.
  Use **Look up translation** to refresh it or see other meanings in the editor.
- Use the three-dot menu beside a word to edit its spelling or translation, or
  delete it from your collection. Hold the word for 1.5 seconds and drag it to
  change its saved order. The page arrows jump through the collection.
- Open **Practice mode** in the side menu to type translations from a shuffled
  copy of your collection. Three wrong answers on a word restart the round.
  You can reveal one answer per eight collected words, rounded up. Asking for
  another reveal after using your allowance also restarts the round. You still
  type each revealed translation to proceed. Finishing or leaving a round
  returns you to your collection.

## Build from source

With Flutter and the Android SDK installed, run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
Official releases must use the same signing key and an increasing Android
version code so Android and Obtainium can install updates in place. The v0.1.0
APK uses the prototype's existing signer for upgrade compatibility. To use that
signer from another build environment, configure the private `android/key.properties`
file with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Keep the
keystore and credentials outside version control.

The [dictionary notices](dictionaries/NOTICE.txt) describe the source data and
how to regenerate the offline dictionary. The [FreeDict source archives](dictionaries/source)
are included in this repository. The [Noto font notice](assets/fonts/NOTICE.txt)
covers the bundled typeface.
