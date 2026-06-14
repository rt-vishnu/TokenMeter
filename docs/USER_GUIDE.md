# PromptPenny — User Guide

PromptPenny is an AI token-usage tracker and cost calculator. It helps you see
how much you're spending across AI providers, chat with models directly, and
collect usage from your own tools — with all your data kept **on your device**.

_Last updated: 2026-06-14_

---

## Getting started

1. Install and open PromptPenny.
2. The app opens on the **Dashboard**. Until you log some usage it will show an
   empty state — that's expected.
3. Pick how you want to use it:
   - **Just chat and track costs** → go to **Chat**, add a provider key, start
     chatting. Every reply is costed automatically.
   - **Track usage from your own code/IDE** → go to **Connect**, enable the API
     server, and wire your tools to it (see [Integration](#connect--api-server)).
   - **View a phone's data on your computer** → use the web build in
     [web client mode](#web-client-mode).

---

## The screens

PromptPenny has six tabs along the bottom:

| Tab | What it does |
|-----|--------------|
| **Home** (Dashboard) | Today / week / month spend, token totals, trends, budget progress, and a tracking streak. |
| **Chat** | Talk to AI models directly; each message's real token cost is recorded. |
| **Calc** (Calculator) | Estimate the cost of a request before you make it. |
| **History** | Every recorded usage event, filterable and exportable to CSV. |
| **Connect** (Integration) | Run the local API server so other tools can report usage; pairing + code snippets. |
| **Settings** | Theme, budgets, currency, API port, HTTPS, custom models, remote connection. |

---

## Chat

The Chat tab talks to each AI provider's API directly using **your own API key**.

### Supported providers

- **Google Gemini**
- **OpenAI**
- **Anthropic Claude**
- **NVIDIA NIM**
- **Kimi (Moonshot AI)**

### Setup

1. Open **Chat** and choose a **Provider** from the dropdown.
2. The first time, you'll be asked for that provider's **API key**. Tap the link
   to get one from the provider, paste the key, and start chatting.
3. Pick a **Model**. Only current (non-deprecated) models for that provider are
   shown.
4. Send a message. The reply streams in, and the **real token counts** reported
   by the provider are used to compute cost and record it automatically.

Your keys are stored securely on the device and are sent **only** to that
provider — never to PromptPenny. You can change or remove a key anytime via the
key icon on the Chat screen.

### Copying messages

Tap the small copy icon under any message (yours or the AI's) to copy its text.

---

## Calculator

Use **Calc** to estimate a request's cost before sending it — choose a model and
enter token counts (or text) to see the projected input/output cost. Nothing is
recorded; it's a what-if tool.

---

## History

Every recorded event (from Chat or from external tools) appears here. You can:

- Filter by **source** (e.g. `chat`, `cursor`, `vscode`) and **model**.
- **Export to CSV** for your own records or spreadsheets.
- Delete individual records.

---

## Budgets & alerts

In **Settings** you can set **daily**, **weekly**, and **monthly** budgets.

- The Dashboard shows progress bars against each budget.
- If you enable **budget alerts**, PromptPenny sends a local notification when
  you approach (warning) or exceed a budget. These notifications are generated
  on your device.

---

## Provider balances (actual spend)

The Dashboard's **Provider balances** card shows your *real* spend or remaining
credit pulled from a provider's billing API — useful to reconcile PromptPenny's
estimates against what the provider actually charged.

- Supported: **OpenRouter** (credit balance), **OpenAI** and **Anthropic**
  (month-to-date cost). These require a provider **admin/billing key**, which is
  separate from your chat key and only reads spend — it can't make requests.
- This is optional. If you don't add a billing key, PromptPenny just shows its
  own tracked estimates.

---

## Connect — API server

The **Connect** tab turns your phone or desktop into a small local server so any
tool, IDE, or script on the **same network** can report token usage into
PromptPenny.

### Enable it

1. Go to **Connect** → toggle **Enable API Server**.
2. You'll see your **endpoint** (e.g. `https://192.168.0.108:8765`), your
   **API key**, and a **QR code**.

### HTTPS (recommended)

By default the server runs over **HTTPS** using a self-signed certificate that
your device generates and keeps locally. Because the server is reached by a
private IP (which no public certificate authority can certify), clients verify
it by its **certificate fingerprint** instead:

- **PromptPenny's own clients** (the web/desktop app) pin the fingerprint
  automatically when you pair — no warnings.
- **Third-party tools** (curl, scripts, IDEs) must skip certificate
  verification, e.g. `curl -k`. The code snippets include the right flag for you.

You can turn HTTPS off in **Settings** (HTTP, for tools that can't handle a
self-signed cert) — only do this on trusted networks.

### Pairing another device

To connect the web app (or another device) to this server:

- **Copy pairing link** — tap it to copy the full URL
  (`https://…?key=…&fp=…`). Paste it into the other device's
  **Settings → Remote API host URL** and it fills in the key and certificate
  pin automatically.
- **QR code** — scan it from the other device using **Settings → Scan QR**
  (available on web and mobile). Easiest when the other device is a phone.

### Code Snippets

The snippets (curl, PowerShell, Python, Node.js) are **ready-made examples** for
sending usage to the server from your own programs. After any AI call in your
code, you forward the token counts to PromptPenny so they show up in your
Dashboard and History. Each snippet is pre-filled with your endpoint and key.

Example payload (`POST /api/v1/usage`):

```json
{ "model": "gpt-4o", "input_tokens": 1200, "output_tokens": 300, "source": "cursor" }
```

If you only use the in-app Chat, you can ignore this screen entirely — it's a
developer feature. See [docs/INTEGRATION.md](INTEGRATION.md) for the full API
reference and IDE setup.

---

## Web client mode

The web build can't host the API server itself. Instead it acts as a **viewer**
for a phone/desktop that does:

1. On the phone, enable the API server (Connect tab).
2. On the web app, go to **Settings**, paste the **pairing link** into the
   **Remote API host URL** field (or use **Scan QR**), and save.
3. The web app now shows that device's dashboard and history.

> **Self-signed certificate note:** the first time you connect over HTTPS, your
> browser will block the self-signed certificate. Open the endpoint directly
> (e.g. `https://192.168.0.108:8765/api/v1/health`) once, choose **Advanced →
> Proceed**, then return to the app. The native app doesn't need this because it
> pins the fingerprint.

---

## Settings reference

- **Dark mode** — toggle theme.
- **Use HTTPS** — encrypt the API server (default on).
- **API port** — change the server port (default `8765`).
- **Remote API host URL / key** — connect the web app to a remote server.
- **Currency** — display currency for costs.
- **Budgets** — daily/weekly/monthly limits and alerts.
- **Custom models** — add a model and its prices if it isn't bundled.

---

## Your privacy in one line

All your usage, costs, history, and API keys stay **on your device**.
PromptPenny has no servers and collects no analytics. See the
[Privacy Policy](PRIVACY_POLICY.md) for details.

---

## Troubleshooting

- **Dashboard shows "All quiet"** — you have no usage in that period yet. Send a
  chat message or report usage from a tool.
- **Connection refused (Connect/web)** — make sure the API server is enabled and
  both devices are on the same Wi-Fi.
- **Certificate error in the web app** — trust the self-signed cert once (see
  [Web client mode](#web-client-mode)).
- **Wrong camera when scanning a QR** — tap the camera-switch icon in the
  scanner; on a laptop, prefer the **Copy pairing link** method instead.
- **Windows Firewall** — allow inbound connections on the API port for the
  PromptPenny app.
- **Invalid API key (chat)** — re-check the key for that provider; each
  provider needs its own.
