# PromptPenny Integration Guide

PromptPenny exposes a local REST API so any IDE, script, or application can
report AI token usage. The mobile or desktop app must be running on the same
Wi-Fi network (or localhost for desktop).

## Quick Start

_Last updated: 2026-06-15_

1. Open PromptPenny and go to **Connect**.
2. Toggle **Enable API Server**.
3. Scan the **pairing QR** or copy the pairing link (endpoint + certificate fingerprint).
4. Enter the **API key** separately in your client (it is not in the QR for security).
5. Send usage after each AI request using one of the snippets below.

## HTTPS and the self-signed certificate

By default the server runs over **HTTPS** with a self-signed certificate that the
device generates and stores locally (toggle in **Settings → Use HTTPS**). Because
the server is reached by a private IP, there is no CA-signed certificate, so:

- **PromptPenny's own clients** (web/desktop app) pin the certificate's SHA-256
  fingerprint automatically when you pair — no warnings.
- **Third-party tools** should use HTTPS and, when possible, verify the
  certificate fingerprint shown on the Connect screen. If your HTTP client cannot
  pin fingerprints, you may need to trust the certificate once in a browser
  (`https://<DEVICE_IP>:8765/api/v1/health` → Advanced → Proceed) or use
  platform-specific trust settings. Avoid disabling TLS verification globally
  (e.g. `NODE_TLS_REJECT_UNAUTHORIZED=0`) unless you understand the risk on
  your local network.

Disabling HTTPS sends traffic in cleartext — only do this on a trusted network,
and expect a confirmation prompt in Settings.

## API Reference

### Base URL

```
https://<DEVICE_IP>:8765
```

Default port is `8765` (configurable in Settings). HTTPS is on by default.
HTTP is available only if you explicitly disable HTTPS in Settings (not recommended).

### Authentication

Protected endpoints require:

```
Authorization: Bearer <API_KEY>
```

Find your API key on the Connect screen.

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/health` | No | Health check |
| GET | `/api/v1/info` | Yes | Device IP, port, app version |
| GET | `/api/v1/models` | Yes | List models and pricing |
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
$env:PROMPT_PENNY_URL = "https://192.168.1.42:8765"
$env:PROMPT_PENNY_API_KEY = "your-api-key"
```

Wire into Cursor via `.cursor/hooks.json` or a task that runs after agent completion.

## VS Code

A full VS Code extension is provided in `integrations/vscode/extension/`. It:

- Shows today's cost in the status bar (refreshes every 30 s via `/api/v1/stats`)
- Provides an `@promptpenny` Copilot Chat participant that auto-reports token usage
- Adds **PromptPenny: Test Connection** and **PromptPenny: Show Status** commands

**Quick setup:**

```bash
cd integrations/vscode/extension
npm install && npm run compile
# Then in VS Code: F1 → "Developer: Install Extension from Location" → pick this folder
```

Configure via VS Code Settings → Extensions → PromptPenny:
- `promptpenny.url` — e.g. `https://127.0.0.1:8765`
- `promptpenny.apiKey` — from the Connect screen

See `integrations/vscode/extension/README.md` for full setup and troubleshooting.

## Python

```bash
pip install requests  # optional, uses stdlib in sample
python integrations/python/report_usage.py --model gpt-4o --input 1200 --output 300 --source cursor
```

## Gemini API (end-to-end test)

Calls Google Gemini, reads real token counts from the response, and posts them to PromptPenny.

**Prerequisites**

1. Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
2. PromptPenny running with **Connect → Enable API Server** ON
3. PC and phone on the same Wi-Fi

**Setup with `.env`**

```powershell
cd integrations/python
pip install -r requirements.txt
copy .env.example .env
# Edit .env with your Gemini and PromptPenny keys

python test_gemini.py
python test_gemini.py --prompt "What is Flutter in one sentence?"
```

`.env` variables: `GEMINI_API_KEY`, `PROMPT_PENNY_URL`, `PROMPT_PENNY_API_KEY`

After it runs, open **Dashboard** and **History** in PromptPenny — you should see a
usage entry with real token counts and cost.

> Self-signed HTTPS note: if `PROMPT_PENNY_URL` is `https://…`, trust the
> certificate once in a browser or configure verification for your environment.

## Dart / Flutter

```dart
import 'package:prompt_penny/integrations/dart/prompt_penny_client.dart';

final client = PromptPennyClient(
  baseUrl: 'https://192.168.1.42:8765',
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

The web build cannot host the API server. In Settings, set **Remote API host URL**
to your phone or desktop endpoint — scan the **pairing QR** or paste the pairing
link (endpoint + certificate fingerprint), then enter the **API key** separately.

> Over HTTPS, the browser must trust the self-signed certificate once: open
> `https://<DEVICE_IP>:8765/api/v1/health` in the browser → **Advanced → Proceed**,
> then return to the app.

## Troubleshooting

- **Connection refused**: Ensure the API server is enabled and both devices are on the same network.
- **Certificate verify failed**: Trust the self-signed cert once in a browser for the web app, or configure your tool to verify the fingerprint from the Connect screen. As a last resort on a trusted LAN only, you may use `curl -k` or `verify=False` — understand that this disables TLS verification.
- **Windows Firewall**: Allow inbound connections on port 8765 for the PromptPenny executable.
- **Android emulator**: Use `10.0.2.2` to reach the host machine, not `localhost`.
- **Invalid API key**: Copy the key from the Connect screen; it is generated per install.
