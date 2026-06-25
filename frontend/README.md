# BakeCity Flutter Frontend

Flutter client for **BakeCity**, a custom-bakery marketplace with customer,
baker and admin roles and escrow payments.

## Architecture

Feature-first, with shared `core/`, `services/` and `widgets/` layers.

```
lib/
├── core/
│   ├── constants/      # app_constants.dart, api_endpoints.dart
│   ├── theme/          # app_theme.dart (Material 3 light + dark)
│   ├── errors/         # app_exception.dart (+ Dio error mapping)
│   ├── storage/        # token_storage.dart (SharedPreferences-backed)
│   └── helpers/        # formatters.dart (KES/intl), validators.dart
├── services/           # Dio + Riverpod providers
│   ├── api_client.dart        # Dio wrapper, auth + logging interceptors
│   ├── auth_service.dart      # register / login / me / logout
│   ├── upload_service.dart    # presign + direct-to-storage upload
│   ├── payment_service.dart   # deposit / balance STK push (stub)
│   ├── notification_service.dart  # FCM init + token registration (stub)
│   ├── websocket_service.dart # realtime order events (stub)
│   └── sms_status_service.dart    # SMS-critical status polling (stub)
├── routes/
│   ├── app_router.dart # GoRouter + auth-based redirect (goRouterProvider)
│   └── app_routes.dart # route path + name constants
├── widgets/            # primary_button, loading_indicator, app_error_view,
│                       # empty_state
├── features/           # one folder per feature, each with:
│   │                   #   presentation/  – screens / views
│   │                   #   application/   – Riverpod controllers / providers
│   │                   #   domain/        – plain-Dart models (fromJson/toJson)
│   ├── auth/           # login, register, splash, auth state notifier
│   ├── onboarding/     # baker KYC / verification flow
│   ├── customer/       # customer home + bottom nav
│   ├── baker/          # baker dashboard + bottom nav
│   ├── discovery/      # search, filters, map placeholder of nearby bakers
│   ├── products/       # catalog + product detail
│   ├── orders/         # orders list + tabbed order detail
│   ├── quotes/         # per-order quotes
│   ├── messaging/      # in-order chat
│   ├── production/     # production stage tracker
│   ├── delivery/       # dispatch + confirm
│   ├── payments/       # escrow deposit / balance
│   ├── disputes/       # raise / track disputes
│   ├── ratings/        # reviews
│   ├── notifications/  # notification list
│   └── profile/        # profile + logout
└── main.dart           # ProviderScope + MaterialApp.router
```

### Key technical notes

- **State management:** Riverpod (`flutter_riverpod`).
- **Navigation:** `go_router`, exposed via `goRouterProvider`. A
  `refreshListenable` bridges `authControllerProvider` so the redirect
  re-runs on auth changes (splash → login → role-specific home).
- **Networking:** `dio`, wrapped by `ApiClient` (`apiClientProvider`) with
  auth-token and logging interceptors; failures map to typed
  `AppException`s.
- **Models:** hand-written plain Dart with `fromJson` / `toJson`. Codegen
  (`freezed` / `json_serializable`) is kept in `pubspec.yaml` for later but
  no generated `.g.dart` / `.freezed.dart` files are referenced yet.

## Getting Started

### Prerequisites
- Flutter 3.x / Dart 3.x

### Setup

```bash
flutter pub get
```

Configure the API base URL (defaults to `http://localhost:8080`) at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

### Code generation

Models are hand-written, so **no codegen is required to run the app**. If you
later migrate any model to `freezed` / `json_serializable`, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Tests

```bash
flutter test
```

### Build

```bash
flutter build apk      # Android
flutter build ios      # iOS
```

## Configuration

See `.env.example`. Build-time configuration is read via `--dart-define`
(e.g. `API_BASE_URL`).
