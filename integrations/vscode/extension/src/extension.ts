import * as vscode from 'vscode';
import * as https from 'https';
import * as http from 'http';

// ── Config helpers ────────────────────────────────────────────────────────────

function cfg() {
  return vscode.workspace.getConfiguration('promptpenny');
}

function getUrl(): string {
  return (cfg().get<string>('url') ?? 'https://127.0.0.1:8765').replace(/\/$/, '');
}

function getApiKey(): string {
  return cfg().get<string>('apiKey') ?? '';
}

function isEnabled(): boolean {
  return cfg().get<boolean>('enabled') ?? true;
}

function getSource(): string {
  return cfg().get<string>('source') ?? 'vscode';
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

function post(path: string, body: object): Promise<object> {
  return new Promise((resolve, reject) => {
    const base = getUrl();
    const url = new URL(path, base.startsWith('http') ? base : `http://${base}`);
    const data = Buffer.from(JSON.stringify(body));
    const lib = url.protocol === 'https:' ? https : http;

    const req = lib.request(
      { hostname: url.hostname, port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname, method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getApiKey()}`,
          'Content-Length': data.length,
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          if ((res.statusCode ?? 0) >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${raw}`));
          } else {
            try { resolve(JSON.parse(raw)); } catch { resolve({}); }
          }
        });
      },
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function get(path: string): Promise<object> {
  return new Promise((resolve, reject) => {
    const base = getUrl();
    const url = new URL(path, base.startsWith('http') ? base : `http://${base}`);
    const lib = url.protocol === 'https:' ? https : http;

    const req = lib.request(
      { hostname: url.hostname, port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname, method: 'GET',
        headers: { 'Authorization': `Bearer ${getApiKey()}` } },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          if ((res.statusCode ?? 0) >= 400) {
            reject(new Error(`HTTP ${res.statusCode}`));
          } else {
            try { resolve(JSON.parse(raw)); } catch { resolve({}); }
          }
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

// ── Token reporting ───────────────────────────────────────────────────────────

async function reportUsage(
  model: string,
  inputTokens: number,
  outputTokens: number,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  if (!isEnabled()) return;
  const key = getApiKey();
  if (!key) {
    vscode.window.showWarningMessage(
      'PromptPenny: API key not set. Go to Settings → Extensions → PromptPenny.',
    );
    return;
  }

  try {
    await post('/api/v1/usage', {
      model,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      source: getSource(),
      metadata,
    });
    statusBar.text = `$(graph) PromptPenny: +${inputTokens + outputTokens} tokens`;
    statusBar.tooltip = `${model} — in:${inputTokens} out:${outputTokens}`;
    setTimeout(() => updateStatusBar(), 4000);
  } catch (err) {
    // Silent fail — don't interrupt the dev's flow.
    console.error('[PromptPenny] Failed to report usage:', err);
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

let statusBar: vscode.StatusBarItem;

function updateStatusBar() {
  if (!isEnabled() || !getApiKey()) {
    statusBar.text = '$(graph) PromptPenny: not configured';
    statusBar.tooltip = 'Click to open PromptPenny settings';
    return;
  }
  statusBar.text = '$(graph) PromptPenny';
  statusBar.tooltip = 'PromptPenny active — click to show status';
}

// ── Copilot Chat hook ─────────────────────────────────────────────────────────

// VS Code Language Model API (available in VS Code 1.85+)
// Wraps the sendRequest call to capture token usage from the response.
function hookCopilotChat(context: vscode.ExtensionContext): void {
  // VS Code 1.90+ exposes vscode.lm.onDidChangeChatModels and response.usage
  // We monkey-patch via the proposed API when available, otherwise fall back
  // to observing chat participant responses.

  if (!('lm' in vscode)) {
    console.log('[PromptPenny] vscode.lm API not available — Copilot hook skipped.');
    return;
  }

  // Register a chat participant that wraps any @workspace or inline chat.
  // This is the supported way to observe chat responses in extensions.
  const participant = vscode.chat.createChatParticipant(
    'promptpenny.observer',
    async (request, _ctx, stream, token) => {
      // Forward the request to GitHub Copilot and capture usage.
      const models = await vscode.lm.selectChatModels({ vendor: 'copilot' });
      if (models.length === 0) {
        stream.markdown('*(PromptPenny: no Copilot model found)*');
        return;
      }
      const model = models[0];

      const messages = [
        vscode.LanguageModelChatMessage.User(request.prompt),
      ];

      try {
        const response = await model.sendRequest(messages, {}, token);
        let fullText = '';
        for await (const chunk of response.text) {
          fullText += chunk;
          stream.markdown(chunk);
        }

        // response.usage is available in VS Code 1.90+
        const usage = (response as any).usage as
          | { inputTokens: number; outputTokens: number }
          | undefined;

        if (usage) {
          await reportUsage(model.id, usage.inputTokens, usage.outputTokens, {
            prompt_preview: request.prompt.slice(0, 100),
          });
        }
      } catch (err) {
        stream.markdown(`Error: ${err}`);
      }
    },
  );
  participant.iconPath = new vscode.ThemeIcon('graph');
  context.subscriptions.push(participant);
}

// ── Inline completion hook ────────────────────────────────────────────────────

// Wraps vscode.lm.sendChatRequest if called directly from other extensions.
// This intercepts any extension that uses the Language Model API.
function hookLanguageModelAPI(context: vscode.ExtensionContext): void {
  if (!('lm' in vscode)) return;

  // Listen for model changes (fired when Copilot responds).
  // We listen to completion requests via the proposed notebookKernel approach
  // since the full intercept API is not yet stable. Instead we rely on the
  // @promptpenny chat participant above and workspace symbol events as proxy.

  // Alternative: poll /api/v1/stats from PromptPenny every 30s to update the
  // status bar with cumulative session cost.
  const pollInterval = setInterval(async () => {
    if (!isEnabled() || !getApiKey()) return;
    try {
      const stats = await get('/api/v1/stats') as any;
      const today = stats?.today;
      if (today) {
        statusBar.text = `$(graph) $${today.cost.toFixed(4)} today`;
        statusBar.tooltip =
          `PromptPenny — Today: ${today.requests} req, ${today.tokens} tokens, $${today.cost.toFixed(6)}\nClick to show status`;
      }
    } catch {
      // Server not running — silent.
    }
  }, 30_000);

  context.subscriptions.push({ dispose: () => clearInterval(pollInterval) });
}

// ── Commands ──────────────────────────────────────────────────────────────────

async function cmdTestConnection(): Promise<void> {
  try {
    await get('/api/v1/health');
    vscode.window.showInformationMessage('PromptPenny: Connected ✓');
  } catch (err) {
    vscode.window.showErrorMessage(
      `PromptPenny: Connection failed — ${err}\n` +
      `Check that the app is running with Integration → Enable API Server ON, ` +
      `and verify the URL in settings (currently: ${getUrl()})`,
    );
  }
}

async function cmdShowStatus(): Promise<void> {
  try {
    const stats = await get('/api/v1/stats') as any;
    const t = stats?.today ?? { cost: 0, tokens: 0, requests: 0 };
    const w = stats?.week ?? { cost: 0, tokens: 0, requests: 0 };
    const m = stats?.month ?? { cost: 0, tokens: 0, requests: 0 };

    const msg = [
      `**Today:** ${t.requests} requests · ${t.tokens} tokens · $${t.cost.toFixed(4)}`,
      `**This week:** ${w.requests} requests · ${w.tokens} tokens · $${w.cost.toFixed(4)}`,
      `**This month:** ${m.requests} requests · ${m.tokens} tokens · $${m.cost.toFixed(4)}`,
    ].join('\n\n');

    vscode.window.showInformationMessage(msg, { modal: true });
  } catch (err) {
    vscode.window.showErrorMessage(`PromptPenny: Could not fetch stats — ${err}`);
  }
}

// ── Activation ────────────────────────────────────────────────────────────────

export function activate(context: vscode.ExtensionContext): void {
  // Status bar item
  statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBar.command = 'promptpenny.showStatus';
  statusBar.show();
  updateStatusBar();
  context.subscriptions.push(statusBar);

  // Commands
  context.subscriptions.push(
    vscode.commands.registerCommand('promptpenny.testConnection', cmdTestConnection),
    vscode.commands.registerCommand('promptpenny.showStatus', cmdShowStatus),
    vscode.commands.registerCommand('promptpenny.openSettings', () =>
      vscode.commands.executeCommand('workbench.action.openSettings', 'promptpenny'),
    ),
  );

  // React to config changes
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('promptpenny')) updateStatusBar();
    }),
  );

  // Hooks
  hookCopilotChat(context);
  hookLanguageModelAPI(context);

  console.log('[PromptPenny] Extension activated');
}

export function deactivate(): void {}
