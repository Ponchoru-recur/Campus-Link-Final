---
date: 2026-05-04
focus: tech
---

# Stack — Campus Link (Luminescence)

## Language & Runtime

| Item | Value |
|------|-------|
| Language | Dart `^3.11.1` |
| Framework | Flutter (mobile, Android focus) |
| Platform targets | Android (primary), iOS (configured but incomplete) |
| Dart SDK constraint | `^3.11.1` |

## Core Framework

- **Flutter** — UI toolkit, Material 3 design via `app_theme.dart` barrel
- **Material 3** — `light_mode.dart` / `dark_mode.dart` themes, `ThemeMode.light` hardcoded in `main.dart:25`

## Key Dependencies

### Firebase Suite
| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | `^4.5.0` | Firebase initialization (`main.dart:13`) |
| `firebase_auth` | `^6.2.0` | Email/password auth, `FirebaseAuth.instance` singleton |
| `cloud_firestore` | `^6.1.3` | NoSQL database, streams for real-time sync |

### Local Storage
| Package | Version | Purpose |
|---------|---------|---------|
| `shared_preferences` | `^2.2.2` | Persist `pending_email`, `pending_role` during email verification |
| `hive_ce` | `^2.19.3` | Offline caching (added, NOT yet initialized) |
| `hive_ce_flutter` | `^2.3.4` | Flutter bindings for Hive (added, NOT yet initialized) |

### UI & Utilities
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_spinkit` | `^5.2.2` | Loading indicators |
| `intl` | `^0.20.2` | Date/time formatting |
| `app_links` | `^7.0.0` | Deep linking |
| `url_launcher` | `^6.3.2` | Launch external URLs |
| `android_intent_plus` | `^6.0.0` | Android platform intents |
| `http` | `^1.6.0` | HTTP requests |
| `logging` | `^1.1.1` | Logging framework |
| `cupertino_icons` | `^1.0.8` | iOS-style icons |

### Dev Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Widget/unit testing |
| `flutter_lints` | `^6.0.0` | Lint rules (`analysis_options.yaml`) |

## Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies, assets (`assets/images/`), Flutter SDK config |
| `android/app/google-services.json` | Firebase Android config — project `campus-link-aac60` |
| `analysis_options.yaml` | Only includes `package:flutter_lints/flutter.yaml` |
| `CLAUDE.md` | Project instructions, architecture notes, conventions |

## Assets

- `assets/images/` — app images, including `avatar.png` used for user avatars
- No custom fonts configured

## Firebase Project

- **Project ID**: `campus-link-aac60`
- **Android App ID**: `com.example.luminescence` (NOT yet updated from default template)
- **No `firestore.rules` file** — security rules must be created before production
- **No iOS config** — `ios/Runner/GoogleService-Info.plist` missing
