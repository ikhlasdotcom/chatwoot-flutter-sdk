# Chatwoot Flutter SDK — Agent Skills

Use this file as the skill guide for improving the Chatwoot Flutter SDK in this repo.

## Scope
This SDK has two surfaces:
- Widget UI: WebView-based `ChatwootWidget` and optional dialog/page UI.
- Client SDK: `ChatwootClient` for API + websocket messaging with local persistence.

## Key entry points
- `ChatwootClient` is the main client entry point. It wires persistence, repository, and callbacks.
- `ChatwootCallbacks` defines event hooks for websocket events and message lifecycle.
- `chatwoot_sdk.dart` exports public APIs. Update this if you add a new public class.

## Architecture map
- DI/providers: `lib/di/modules.dart` (Riverpod + Dio + Hive)
- Repository: `lib/data/chatwoot_repository.dart`
- Remote services: `lib/data/remote/service/` (Dio API + websocket)
- Models (remote): `lib/data/remote/requests/`, `lib/data/remote/responses/`
- Local storage: `lib/data/local/` (Hive entities + DAOs + LocalStorage)
- UI: `lib/ui/` (dialog/page theme, widget)

## How to enhance features
### Add a new API call
1. Create request/response models in `lib/data/remote/requests` or `lib/data/remote/responses`.
2. Add a method in `ChatwootClientService` (remote service).
3. Expose the behavior in `ChatwootRepositoryImpl` and then in `ChatwootClient`.
4. If the new call impacts storage, update `LocalStorage` and relevant DAOs.

### Add a new websocket event
1. Extend `ChatwootEvent` parsing in `lib/data/remote/responses/chatwoot_event.dart`.
2. Add a callback in `ChatwootCallbacks`.
3. Handle it in `ChatwootRepositoryImpl.listenForEvents`.

### Add or modify local persistence
1. Add/adjust Hive entities in `lib/data/local/entity/`.
2. Update DAOs in `lib/data/local/dao/`.
3. Update `LocalStorage` to include new DAO(s).
4. Run codegen if needed.

### Adjust UI
- `ChatwootWidget` lives under `lib/ui/webview_widget/`.
- Dialog/page UI components are in `lib/ui/`.
- If you add UI options, surface them via public constructors and update README usage.

## Behavior notes
- Client instances are keyed by baseUrl + inbox + user identifier (+ optional conversation context/id). See `ChatwootClient.getClientInstanceKey`.
- Persistence is optional. When enabled, Hive stores contact, conversation, messages, and user info.
- `listenForEvents` manages websocket presence and message events; ensure new events do not break timers.

## Build tips
- For codegen or Hive adapters, run: `dart run build_runner build --delete-conflicting-outputs`.
- Keep README examples in sync with public API changes.
