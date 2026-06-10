# TokenMeter Integration Guide

TokenMeter exposes a local REST API so any IDE, script, or application can report AI token usage. The mobile or desktop app must be running on the same Wi-Fi network (or localhost for desktop).

## Quick Start

1. Open TokenMeter and go to **Integration**.
2. Toggle **Enable API Server**.
3. Copy the endpoint URL and API key (or scan the QR code).
4. Send usage after each AI request using one of the snippets below.

## API Reference

### Base URL

```
http://<DEVICE_IP>:8765
```

Default port is `8765` (configurable in Settings).

### Authentication

Protected endpoints require:

```
Authorization: Bearer <API_KEY>
```

Find your API key on the Integration screen.

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/health` | No | Health check |
| GET | `/api/v1/info` | No | Device IP, port, app version |
| GET | `/api/v1/models` | No | List models and pricing |
| GET | `/api/v1/usage` | Yes | Query usage history (`?limit=N&offset=N&from=&to=&source=&model=`) |
| POST | `/api/v1/usage` | Yes | Record a usage event |
| DELETE | `/api/v1/usage/:id` | Yes | Delete a usage record by ID |
| GET | `/api/v1/stats` | Yes | Today / week / month aggregates |
| POST | `/api/v1/estimate` | Yes | Estimate cost without saving |

### POST /api/v1/usage

```json
{
  "model": "gpt-4o",
  "input_tokens": 1523,
  "output_tokens": 412,
  "source": "cursor",
  "session_id": "chat-abc",
  "timestamp": "2026-06-10T10:00:00Z",
  "metadata": { "file": "main.dart" }
}
```

Required fields: `model`, `input_tokens`, `output_tokens`.

### POST /api/v1/estimate

```json
{
  "model": "gpt-4o",
  "input_tokens": 1000,
  "output_tokens": 500
}
```

Or estimate from text:

```json
{
  "model": "gpt-4o",
  "prompt_text": "Your prompt here...",
  "completion_text": "Model response..."
}
```

## Cursor

Use a post-request hook or custom command. Example PowerShell script:

```powershell
# integrations/cursor/report_usage.ps1
.\integrations\cursor\report_usage.ps1 -Model "gpt-4o" -InputTokens 1200 -OutputTokens 300
```

Set environment variables:

```powershell
$env:TOKEN_METER_URL = "http://192.168.1.42:8765"
$env:TOKEN_METER_API_KEY = "your-api-key"
```

Wire into Cursor via `.cursor/hooks.json` or a task that runs after agent completion.

## VS Code

A full VS Code extension is provided in `integrations/vscode/extension/`. It:

- Shows today's cost in the status bar (refreshes every 30 s via `/api/v1/stats`)
- Provides an `@tokenmeter` Copilot Chat participant that auto-reports token usage
- Adds **TokenMeter: Test Connection** and **TokenMeter: Show Status** commands

**Quick setup:**

```bash
cd integrations/vscode/extension
npm install && npm run compile
# Then in VS Code: F1 → "Developer: Install Extension from Location" → pick this folder
```

Configure via VS Code Settings → Extensions → TokenMeter:
- `tokenmeter.url` — e.g. `http://127.0.0.1:8765`
- `tokenmeter.apiKey` — from Integration screen

See `integrations/vscode/extension/README.md` for full setup and troubleshooting.

## Python

```bash
pip install requests  # optional, uses stdlib in sample
python integrations/python/report_usage.py --model gpt-4o --input 1200 --output 300 --source cursor
```

## Gemini API (end-to-end test)

Calls Google Gemini, reads real token counts from the response, and posts them to TokenMeter.

**Prerequisites**

1. Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
2. TokenMeter running with **Integration → Enable API Server** ON
3. PC and phone on the same Wi-Fi

**Setup with `.env`**

```powershell
cd integrations/python
pip install -r requirements.txt
copy .env.example .env
# Edit .env with your Gemini and TokenMeter keys

python test_gemini.py
python test_gemini.py --prompt "What is Flutter in one sentence?"
```

`.env` variables: `GEMINI_API_KEY`, `TOKEN_METER_URL`, `TOKEN_METER_API_KEY`

After it runs, open **Dashboard** and **History** in TokenMeter — you should see a `gemini-api-test` entry with real token counts and cost for `gemini-2.0-flash`.

## Dart / Flutter

```dart
import 'package:token_meter/integrations/dart/token_meter_client.dart';

final client = TokenMeterClient(
  baseUrl: 'http://192.168.1.42:8765',
  apiKey: 'your-api-key',
);
await client.reportUsage(
  model: 'gpt-4o',
  inputTokens: 1200,
  outputTokens: 300,
  source: 'my_app',
);
```

## Web Dashboard

The web build cannot host the API server. In Settings, set **Remote API host URL** to your phone or desktop endpoint (e.g. `http://192.168.1.42:8765`).

## Troubleshooting

- **Connection refused**: Ensure the API server is enabled and both devices are on the same network.
- **Windows Firewall**: Allow inbound connections on port 8765 for the TokenMeter executable.
- **Android emulator**: Use `10.0.2.2` to reach the host machine, not `localhost`.
- **Invalid API key**: Copy the key from Integration screen; it is generated per install.
