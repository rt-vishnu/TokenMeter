# TokenMeter

Cross-platform Flutter app for tracking AI token usage and calculating model costs. Exposes a local REST API so any IDE or application can report usage over your Wi-Fi network.

## Features

- **Dashboard** — daily, weekly, and monthly spend with charts by model and source
- **Calculator** — estimate costs from token counts or text
- **History** — searchable log of all usage events
- **Integration** — local API server with QR pairing and copy-paste snippets
- **Settings** — custom model pricing, API port, dark mode, web remote host

## Getting Started

```bash
flutter pub get
dart run build_runner build
flutter run
```

### Platforms

| Platform | Role |
|----------|------|
| Android / iOS | API host + full UI |
| Windows / macOS / Linux | API host + full UI |
| Web | Dashboard client — set remote API URL in Settings |

### Windows Firewall

When running on desktop, allow inbound TCP on port **8765** (or your configured port) for the TokenMeter executable.

## IDE Integration

1. Open **Integration** and enable the API server.
2. Copy the endpoint and API key.
3. Send `POST /api/v1/usage` after each AI request.

See [docs/INTEGRATION.md](docs/INTEGRATION.md) for full API reference and samples for Cursor, VS Code, Python, and Dart.

## Project Structure

```
lib/
  core/          # models, services, providers
  data/          # drift database, repositories
  features/      # dashboard, calculator, history, integration, settings
integrations/    # sample clients for IDEs
docs/            # integration guide
```

## Tests

```bash
flutter test
```
