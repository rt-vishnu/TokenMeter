# TokenMeter VS Code Extension

Automatically tracks GitHub Copilot Chat token usage and shows live session cost in the status bar.

---

## What it does

- Shows today's cost in the VS Code status bar, refreshed every 30 seconds
- `@tokenmeter` chat participant — ask it questions and it routes through Copilot while reporting token usage to TokenMeter automatically
- **TokenMeter: Test Connection** command — verify the app is reachable
- **TokenMeter: Show Status** command — pop-up with today / week / month cost breakdown

---

## Prerequisites

1. **TokenMeter desktop app** running on Windows/Mac/Linux (same machine as VS Code, or same Wi-Fi)
2. **GitHub Copilot** extension installed in VS Code (for automatic chat tracking)
3. **Node.js** (any recent LTS) — only needed to build the extension once

---

## Setup (one-time, ~3 minutes)

### Step 1 — Start the TokenMeter API server

1. Open the TokenMeter app
2. Go to **Integration** tab
3. Toggle **Enable API Server** ON
4. Note the **Endpoint** URL (e.g. `http://192.168.0.108:8765`)
5. Reveal and copy the **API Key**

### Step 2 — Build the extension

Open a terminal in this folder (`integrations/vscode/extension`) and run:

```bash
npm install
npm run compile
```

This produces an `out/extension.js` file.

### Step 3 — Load the extension in VS Code

**Option A — Load directly (development mode, easiest):**

1. In VS Code, press `F1` → type **"Developer: Install Extension from Location"**
2. Browse to this folder (`integrations/vscode/extension`) → click **OK**
3. Reload VS Code when prompted

**Option B — Package as .vsix (install once, persists across restarts):**

```bash
npm install -g @vscode/vsce
vsce package
# Creates tokenmeter-vscode-1.0.0.vsix
```

Then in VS Code: `F1` → **"Extensions: Install from VSIX"** → pick the `.vsix` file.

### Step 4 — Configure the extension

1. In VS Code: `F1` → **"TokenMeter: Open Settings"** (or go to Settings → Extensions → TokenMeter)
2. Set **URL**: `http://127.0.0.1:8765` (if TokenMeter is on the same PC) or `http://<PHONE_IP>:8765`
3. Set **API Key**: paste the key you copied in Step 1

### Step 5 — Verify

Run `F1` → **"TokenMeter: Test Connection"** — you should see "Connected ✓".

The status bar (bottom right) will show `$(graph) $0.0000 today`.

---

## Using the @tokenmeter chat participant

In the Copilot Chat panel, type:

```
@tokenmeter what is agentic RAG?
```

This routes your question through GitHub Copilot and automatically reports the token count to TokenMeter. After it responds, check the Dashboard — a new entry appears.

---

## Manual reporting (for your own scripts)

If you run Python scripts that call AI APIs (like `test_gemini.py`), use the existing helper:

```powershell
# From the project root
python integrations/python/report_usage.py `
  --model gemini-2.5-flash-lite `
  --input 1200 `
  --output 300 `
  --source vscode
```

Or set env vars once in your shell profile so you never have to type them:

```powershell
# Add to your PowerShell profile ($PROFILE)
$env:TOKEN_METER_URL     = "http://127.0.0.1:8765"
$env:TOKEN_METER_API_KEY = "your-api-key-here"
```

Then just:

```powershell
python .\integrations\python\test_gemini.py --prompt "what is agentic RAG?"
```

---

## Status bar

| Display | Meaning |
|---------|---------|
| `$(graph) $0.0042 today` | Connected, shows today's total cost (refreshes every 30s) |
| `$(graph) TokenMeter` | Connected but no usage yet today |
| `$(graph) TokenMeter: not configured` | API key not set in settings |

Click the status bar item at any time to see Today / Week / Month breakdown.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Connection failed" | Ensure TokenMeter has Integration → Enable API Server ON. Check the URL in settings matches what the app shows. |
| Status bar stuck on "not configured" | Open TokenMeter settings (`F1` → TokenMeter: Open Settings) and paste your API key. |
| `@tokenmeter` not appearing in chat | Reload VS Code after installing the extension. |
| Token counts showing 0 | Your VS Code version may not expose `response.usage` yet — update to VS Code 1.90+. The @tokenmeter participant still works; usage just won't be captured automatically for inline suggestions. |
| Windows Firewall blocking | Allow inbound connections on port 8765 for `flutter_application_2.exe`. |
