# ReemGym

Diet and exercise tracker built with Flutter. Photograph a meal and get its
calories, macros and nutrients; log workouts; count steps; track everything
against a daily plan built from your profile.

## Features

- **Onboarding**: name, sex, age, height, weight, activity level and goal produce
  a daily calorie, macro, water and step plan (Mifflin–St Jeor formula).
- **Food logging**: scan a meal with the camera, pick a photo, describe it in
  words, enter it by hand, or re-log a recent meal. Every AI result opens in a
  review screen where items, portions and nutrients can be corrected.
- **Exercise logging**: 30+ activities with calories from MET values and your
  weight, plus custom activities.
- **Steps**: daily total from Apple Health / Health Connect (counted by the
  phone even while the app is closed) plus live walking/running detection.
- **Water and weight** tracking, progress charts, averages and a logging streak.
- **Sync**: Google sign-in (Firebase Auth) and Cloud Firestore, so data
  follows the account to any device.

## Firebase setup

The app uses two Firebase projects:

| Project | Used for | Plan | Config file |
| --- | --- | --- | --- |
| `reemgym` | Sign-in, Firestore data, meal photos (Storage) | Blaze (needed for Storage) | `lib/firebase_options.dart` |
| `reemgym-ai` | Shared Gemini allowance through AI Logic only | Spark (free) | `lib/firebase_options_ai.dart` |

They are separate because a project with billing has no free Gemini tier: with
one project, every user's scans would be charged to the owner. Keep
`reemgym-ai` on the free plan.

Users can also add their own Gemini key in Profile; it is stored only on their
device and takes over from the shared allowance.

Deploy rules to the main project with:

```sh
firebase deploy --only firestore,auth      # database, rules, Google sign-in
firebase deploy --only storage             # photo rules (after the Blaze upgrade)
```

To regenerate a config file, run `flutterfire configure` with
`--project=<id> --out=<file>`. Running it for `reemgym-ai` overwrites
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` and
`firebase.json`; run it for `reemgym` last so those point at the main project.

Before releasing, turn on Firebase App Check in both projects so only this app
can use them.

### Config files are not in the repository

`lib/firebase_options.dart` and `lib/firebase_options_ai.dart` are committed
as placeholders, and `google-services.json` / `GoogleService-Info.plist` are
git-ignored. After cloning, create your own Firebase projects and run
`flutterfire configure` for each (see above) before building for a phone. The
Google sign-in client IDs in `lib/services/auth_service.dart` and
`ios/Runner/Info.plist` also belong to the original project and must be
replaced with yours.

## Google sign-in

Each signing key must be registered with the Android app in the `reemgym`
project, or Google sign-in fails with a configuration error. The debug key of
this machine is registered. For a release build, add its SHA-1 and SHA-256:

```sh
firebase apps:android:sha:create <android app id> <fingerprint> --project reemgym
```

Android emulators started from Android Studio sometimes cannot resolve host
names. Start the emulator with `-dns-server 8.8.8.8,1.1.1.1` if the app says
there is no internet connection.

## Research data

When a user turns on "Share meals for research" (off by default), each
analysed meal is saved as a photo at `users/{uid}/meals/{entryId}` in Storage
and a record at `users/{uid}/analyses/{entryId}` in Firestore holding the AI
estimate, the user's corrected version, the model and any text description.
Read all users' records with a collection-group query on `analyses` from the
Admin SDK.

## Desktop preview

On platforms without Firebase config (macOS desktop) the app starts in preview
mode: any email signs in and nothing is saved.

## Platform notes

- **iOS**: open `ios/Runner.xcworkspace` in Xcode, pick your team, and add the
  **HealthKit** capability (the entitlements file is already in place).
- **Android**: step totals come from Health Connect (built in on Android 14+,
  a Play Store app on older versions). Minimum Android version is 8.0.

## Code map

| Path | What it holds |
| --- | --- |
| `lib/models.dart` | Profile, food, exercise and day models |
| `lib/nutrition_calc.dart` | Plan maths, calorie formulas, activity list |
| `lib/services/` | Auth, Firestore, Gemini food analysis, own-key storage, research capture, step counting |
| `lib/screens/` | Sign-in, onboarding, dashboard, logging, progress, profile |
| `lib/theme.dart`, `lib/widgets/` | Design tokens and shared widgets |

The Gemini model name is the `geminiModel` constant in
`lib/services/food_analyzer.dart`.
