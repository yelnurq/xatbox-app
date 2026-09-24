# Flavor / environment configuration

The app reads its configuration from `--dart-define` values, never from
source code (ТЗ п.24.28, "Нет hardcoded secrets"):

| Define                | Values                 | Notes                                                        |
|-----------------------|------------------------|--------------------------------------------------------------|
| `XATBOX_FLAVOR`       | `dev`, `stage`, `prod` | Default `dev`.                                               |
| `XATBOX_API_BASE_URL` | URL incl. `/api/v1`    | Required for `stage`/`prod`. `dev` falls back to localhost.  |
| `XATBOX_CHAT_BASE_URL` | Chat Service URL incl. `/api/v1` | Empty = chat tab disabled. `dev` falls back to `http://localhost:8090/api/v1`. |
| `XATBOX_CALLS_BASE_URL` | Call Service URL incl. `/api/v1` | Empty = calls disabled (needs chat too: signalling goes over the chat socket). `dev` falls back to `http://localhost:8095/api/v1`. The LiveKit URL is never configured in the app: it comes with each call token. |
| `XATBOX_FIREBASE_API_KEY`, `XATBOX_FIREBASE_APP_ID`, `XATBOX_FIREBASE_SENDER_ID`, `XATBOX_FIREBASE_PROJECT_ID` | Firebase project values | Fallback when there is no `google-services.json` (see "Push" below). All four required; otherwise push stays off. `XATBOX_FIREBASE_APP_ID` is the **Android** app id. |
| `XATBOX_FIREBASE_IOS_APP_ID` | Firebase iOS app id (`1:…:ios:…`) | A Firebase app id belongs to one platform, so iOS builds use this one when set (otherwise `XATBOX_FIREBASE_APP_ID`, as before). See `docs/IOS.md`. |

Copy the example for the flavor you need and fill in the real values.
Real `*.json` files are git-ignored.

```bash
cp env/prod.json.example env/prod.json     # edit the URL
flutter run --dart-define-from-file=env/prod.json
flutter build apk --release --dart-define-from-file=env/prod.json
```

`prod` refuses non-`https` URLs at startup.

## Push (Firebase Cloud Messaging, encrypted)

Android push goes through FCM, but Google only sees ciphertext: the app
registers a random per-install AES-256 key with the Chat Service, which
encrypts every payload (text, sender/chat/caller names) for that device. The
app decrypts it (also when killed) and shows the notification itself.

What the build machine (Windows) needs:

1. **`android/app/google-services.json`** — download it from the Firebase
   console (Project settings → Your apps → Android app with package name
   `kz.xatbox.xatbox_mobile`) and put it exactly there. It is git-ignored.
   When the file exists the build applies the `com.google.gms.google-services`
   Gradle plugin automatically, so the default FirebaseApp is configured
   natively — required for reliable delivery while the app is killed.
2. Without the file the app falls back to the four `XATBOX_FIREBASE_*`
   dart-defines above (works while the app process can start Firebase itself;
   prefer the JSON file for release builds).

Server side (`backend/deploy/README.md`, "FCM (Android)"): the same Firebase
project's service-account JSON in `deploy/secrets/fcm/` with
`FCM_SERVICE_ACCOUNT_JSON` / `FCM_PROJECT_ID`, and optionally
`PUSH_KEY_ENCRYPTION_KEY` (`openssl rand -base64 32`).

Android 13+ asks for the notification permission (POST_NOTIFICATIONS) right
after sign-in. Channels created at start: `chat_messages` («Сообщения»),
`calls` («Звонки»), `calendar` («Календарь»).
