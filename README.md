# XatBox

Flutter client of XatBox — mail, messenger, calendar and calls — for
Android, iOS, Windows, macOS and Linux from one code base.

This repository holds the app sources and the build workflows only. Server
addresses, Firebase keys and signing keys are never stored here: the
workflows take them from repository secrets.

## Building

Builds run in GitHub Actions (Actions → the workflow → Run workflow):

| Workflow | Output |
|---|---|
| Android build | signed APKs per ABI and a universal APK |
| Windows desktop build | installer and portable zip |
| Linux desktop build | .deb and tar.gz |
| macOS desktop build | app zip and dmg |
| CI | `flutter analyze` and `flutter test` |

Repository secrets:

* `XATBOX_ENV_JSON` — the build configuration, see [`env/README.md`](env/README.md).
* `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
  `ANDROID_KEY_ALIAS` — the Android upload key.
* Optional Windows code signing: `WINDOWS_SIGN_PFX_BASE64`, `WINDOWS_SIGN_PASSWORD`,
  or Azure Trusted Signing (`AZURE_*`, `TRUSTED_SIGNING_*`).

Locally:

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=env/dev.json
flutter analyze && flutter test
```
