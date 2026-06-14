# PromptPenny — Privacy Policy

_Last updated: 2026-06-14_

PromptPenny is designed to be **local-first**. Your usage data, costs, history,
and API keys live on your own device. We do not operate any servers that receive
your data, and we do not collect analytics, telemetry, or tracking information.

This policy explains what is stored, where, and the only situations in which data
leaves your device — always to a destination you choose.

---

## Summary

- **No PromptPenny servers.** There is no backend that your data is sent to.
- **No analytics or tracking.** The app contains no analytics SDKs, crash
  reporters, advertising IDs, or telemetry.
- **Your data stays on your device** in local storage.
- **Your API keys** are stored in your operating system's secure storage and are
  sent only to the AI provider you choose.
- Data leaves your device **only** when you: chat with a provider, sync provider
  balances, or connect to your own local API server.

---

## What data PromptPenny stores

All of the following is stored **locally on your device only**:

- **Usage records** — model name, input/output token counts, computed cost,
  source label, timestamp, and optional metadata. Metadata may include a short
  preview of a prompt (for example, the first ~120 characters of a chat message)
  to help you identify a record.
- **Settings** — theme, currency, budgets, API port, and HTTPS preference.
- **API keys** — for chat providers and (optionally) provider billing.
- **A locally generated server API key** and **self-signed TLS certificate**
  used by the local API server feature.

This data is stored in:

- A local database file on the device (usage history).
- The operating system's **secure storage** for secrets — Keychain (iOS/macOS),
  Keystore (Android), or DPAPI-protected storage (Windows). API keys and the
  TLS private key are kept here.

PromptPenny does not transmit this data to us or to any third party except as
described below.

---

## When data leaves your device

PromptPenny makes network connections only in these cases, and only to
destinations you configure:

### 1. Chatting with an AI provider

When you use the **Chat** feature, your messages and conversation history are
sent **directly** to the AI provider you selected, using your API key:

- Google Gemini, OpenAI, Anthropic, NVIDIA NIM, or Kimi (Moonshot AI).

Your prompts and the model's responses are processed by that provider under
**their** privacy policy and terms. PromptPenny does not receive a copy.

### 2. Syncing provider balances (optional)

If you add a billing/admin key on the **Provider balances** screen, PromptPenny
calls that provider's billing API (OpenRouter, OpenAI, or Anthropic) using your
key to read your spend or remaining credit. This data is shown to you and cached
locally; it is not sent anywhere else.

### 3. The local API server (optional)

If you enable the API server on the **Connect** screen, your device hosts a local
REST endpoint on your network so your own tools can report usage. When another
device or tool connects:

- Usage data travels over your **local network** between your devices.
- By default the connection is encrypted with **HTTPS** using a self-signed
  certificate generated on your device; clients verify it by certificate
  fingerprint.
- Requests require the server **API key** for authentication, and the server
  applies basic rate limiting.

No data from the API server is sent to PromptPenny or any third party — it stays
between the devices you connect.

---

## Third-party AI providers

When you supply your own API key and send requests, the relevant provider
receives your prompts/usage and handles them under its own policies. Please
review:

- Google Gemini — Google AI / Google Cloud terms
- OpenAI — OpenAI privacy policy
- Anthropic — Anthropic privacy policy
- NVIDIA NIM — NVIDIA terms
- Kimi (Moonshot AI) — Moonshot AI terms

PromptPenny is not responsible for how these providers process data you send to
them.

---

## Analytics, tracking, and advertising

PromptPenny contains **none** of the following: analytics or usage telemetry,
crash/error reporting services, advertising or ad identifiers, third-party
trackers, or fingerprinting. We do not build user profiles and there is nothing
to opt out of.

---

## Data retention and deletion

Because your data is local, **you** control it:

- Delete individual usage records from the **History** screen.
- Remove an API key anytime from the Chat key dialog or Settings.
- Regenerate the server API key from the Connect screen.
- Uninstalling the app removes its local database and stored secrets from the
  device (subject to your OS's uninstall behavior).

We cannot delete your data for you, because we never have it.

---

## Children's privacy

PromptPenny is a developer/productivity tool and is not directed at children. It
does not knowingly collect personal information from anyone, as it collects no
personal data centrally at all.

---

## Security

- Secrets (API keys, the TLS private key) are stored in OS-provided secure
  storage rather than plain files.
- The local API server defaults to HTTPS and requires an API key.
- Because the server uses a self-signed certificate for private-network use,
  PromptPenny's own clients pin its fingerprint to prevent tampering.

No method of transmission or storage is perfectly secure, but PromptPenny
minimizes risk by keeping data local and avoiding any central collection.

---

## Changes to this policy

If the app's data practices change, this document will be updated and the
"Last updated" date revised. Material changes will be noted in the app's release
notes.

---

## Contact

Questions about this policy or PromptPenny's data handling:

- **Contact:** ravi.vishnubhotla123@gmail.com
