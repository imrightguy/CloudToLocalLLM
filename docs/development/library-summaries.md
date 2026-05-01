# Library Quick Reference

This file contains concise, project-relevant summaries for commonly used libraries and integration notes collected during repository analysis. These are short actionable reminders for developers and AI agents working in this repo.

- **`web_socket_channel`**: Cross-platform WebSocket wrapper for Dart/Flutter. Use `WebSocketChannel.connect(Uri)`; implementations include `IOWebSocketChannel` (desktop/server) and `HtmlWebSocketChannel` (web). Read stream with `channel.stream.listen(...)` and send with `channel.sink.add(...)`. No built-in reconnection—implement externally. Close with `channel.sink.close()` and monitor `closeCode`/`closeReason`.

- **`get_it`**: Service locator / dependency injection. Use `GetIt.instance` to register services (`registerSingleton`, `registerLazySingleton`, `registerFactory`, `registerSingletonAsync`). For async setup use `registerSingletonAsync` + `allReady()` or `isReady()`. Use `pushNewScope`/`popScope` for scoping in tests or nested modules and `reset()` to clear registrations during teardown.

- **`provider`**: Flutter state management helper. Common providers: `ChangeNotifierProvider`, `Provider`, `FutureProvider`, `StreamProvider`. Consume with `context.watch<T>()`, `context.read<T>()`, `context.select<T, R>()`, or `Consumer<T>`. Avoid `Provider.value` for newly created objects; be careful reading providers in `initState` (use `read` not `watch` there).

- **`rxdart`**: Reactive stream utilities that extend Dart Streams with Subjects, transformers, and useful operators. Use `BehaviorSubject` for current-value streams, `PublishSubject` for transient events. Useful in `StreamingMessage` patterns; remember to close subjects to avoid leaks.

- **`langchain` (Python)**: Framework for building LLM-based chains and agents. Key concepts: `Chains`, `Agents`, `Tools`, `Memory` stores (InMemory, Redis, Postgres), and streaming. When using Ollama as an optional support model provider, prefer the `langchain_ollama` connector for compatibility and streaming. Use checkpointers and memory stores for long-running chains.

- **`langchain_ollama`**: Connector enabling LangChain to talk to Ollama local models; supports streaming outputs. Pay attention to model name compatibility and Ollama server endpoints; handle timeouts and local server availability.

- **`sqflite_common_ffi`**: SQLite support for desktop and tests. Initialize with `sqfliteFfiInit()` and use `databaseFactoryFfi` as the factory. Packaging notes: ensure the target platform has SQLite available (libsqlite3, sqlite3.dll), and be mindful when running in isolates or CI containers.

- **`flutter_secure_storage_x`**: Cross-platform secure key-value store. Use for storing tokens and secrets. Platform caveats: on web it requires HTTPS (localhost allowed in dev), on Linux it may depend on libsecret, on macOS uses Keychain; check platform options for keychain/service names. For large secrets or cross-process access, confirm platform-specific limitations.

- **`dio`**: Primary HTTP client in this project (preferred over legacy `http`). Features: interceptors, form-data, request cancellation, timeouts, advanced configuration. Use a shared configured `Dio` instance (inject via `get_it`) and centralize interceptors (auth, logging, retry). For streaming downloads/uploads use `onReceiveProgress`/`onSendProgress` and `ResponseType.stream`.

- **`go_router`**: Declarative, URL-based Flutter router. Supports nested `ShellRoute`, parameterized paths, redirects, and deep linking. Use `refreshListenable` and `redirect` callbacks for auth-based navigation changes. Watch version migration notes when upgrading major versions.

---

If you'd like, I can:

- Add short usage snippets for each library (2–3 lines each).
- Commit the file (I will commit & push it now). If you prefer a different file path or format, tell me and I'll adapt.
