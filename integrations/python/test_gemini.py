#!/usr/bin/env python3
"""
Call Gemini API, then report real token usage to PromptPenny.

Setup:
  cd integrations/python
  copy .env.example .env
  # Edit .env with your keys

  pip install -r requirements.txt
  python test_gemini.py
  python test_gemini.py --prompt "Explain quantum computing in 2 sentences"
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

from dotenv import load_dotenv

_SCRIPT_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _SCRIPT_DIR.parent.parent

# Use a current model id — bare "gemini-1.5-flash" and "gemini-2.0-flash" are retired.
DEFAULT_GEMINI_MODEL = "gemini-2.5-flash-lite"
DEFAULT_PROMPT_PENNY_URL = "https://127.0.0.1:8765"
DEFAULT_PROMPT = "Reply with exactly one short sentence about token usage tracking."


def list_gemini_models(api_key: str) -> list[str]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    with urllib.request.urlopen(url, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    models = []
    for item in data.get("models", []):
        name = item.get("name", "")
        methods = item.get("supportedGenerationMethods", [])
        if "generateContent" in methods:
            models.append(name.removeprefix("models/"))
    return sorted(models)


def gemini_quota_help() -> str:
    return (
        "\nGemini free-tier quota exceeded. Try one of:\n"
        "  • Wait and retry (error may include a retry delay)\n"
        "  • Check usage: https://ai.dev/rate-limit\n"
        "  • Try another model in .env: GEMINI_MODEL=gemini-2.5-flash-lite\n"
        "  • List models your key supports: python test_gemini.py --list-models\n"
        "  • Enable billing in Google AI Studio for paid quota\n"
        "  • Test PromptPenny only (skip Gemini): python test_gemini.py --prompt-penny-only"
    )


def load_env() -> None:
    """Load .env from integrations/python, then project root."""
    for env_path in (_SCRIPT_DIR / ".env", _PROJECT_ROOT / ".env"):
        if env_path.is_file():
            load_dotenv(env_path)
            return
    load_dotenv()


def call_gemini(api_key: str, prompt: str, model: str = DEFAULT_GEMINI_MODEL) -> dict:
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )
    body = json.dumps(
        {"contents": [{"parts": [{"text": prompt}]}]}
    ).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def report_to_prompt_penny(
    base_url: str,
    api_key: str,
    model: str,
    input_tokens: int,
    output_tokens: int,
    source: str,
    metadata: dict,
) -> dict:
    url = f"{base_url.rstrip('/')}/api/v1/usage"
    payload = {
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "source": source,
        "metadata": metadata,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    load_env()

    parser = argparse.ArgumentParser(
        description="Test Gemini API and report usage to PromptPenny"
    )
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--gemini-key", default=os.environ.get("GEMINI_API_KEY", ""))
    parser.add_argument(
        "--prompt-penny-url",
        default=os.environ.get("PROMPT_PENNY_URL", DEFAULT_PROMPT_PENNY_URL),
    )
    parser.add_argument(
        "--prompt-penny-key",
        default=os.environ.get("PROMPT_PENNY_API_KEY", ""),
    )
    parser.add_argument(
        "--gemini-model",
        default=os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL),
    )
    parser.add_argument(
        "--prompt-penny-model",
        default=os.environ.get("PROMPT_PENNY_MODEL", ""),
        help="Model id for cost lookup in PromptPenny (defaults to GEMINI_MODEL)",
    )
    parser.add_argument(
        "--source",
        default=os.environ.get("PROMPT_PENNY_SOURCE", "gemini-api-test"),
    )
    parser.add_argument(
        "--list-models",
        action="store_true",
        help="List Gemini models available for your API key, then exit",
    )
    parser.add_argument(
        "--prompt-penny-only",
        action="store_true",
        help="Skip Gemini API; send sample token counts to PromptPenny only",
    )
    parser.add_argument("--input", type=int, default=50, dest="input_tokens")
    parser.add_argument("--output", type=int, default=20, dest="output_tokens")
    args = parser.parse_args()

    prompt_penny_model = args.prompt_penny_model or args.gemini_model

    if args.list_models:
        if not args.gemini_key:
            sys.exit("Missing GEMINI_API_KEY in .env")
        try:
            models = list_gemini_models(args.gemini_key)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            sys.exit(f"Failed to list models ({e.code}): {body}")
        print("Models supporting generateContent:\n")
        for name in models:
            print(f"  {name}")
        sys.exit(0)

    if not args.prompt_penny_key:
        sys.exit(
            "Missing PROMPT_PENNY_API_KEY.\n"
            "Add it to integrations/python/.env (from PromptPenny → Integration)."
        )

    if args.prompt_penny_only:
        input_tokens = args.input_tokens
        output_tokens = args.output_tokens
        print("1) Skipping Gemini (--prompt-penny-only)")
        print(f"   Using sample tokens — input: {input_tokens}, output: {output_tokens}")
    else:
        if not args.gemini_key:
            sys.exit(
                "Missing GEMINI_API_KEY.\n"
                "Copy integrations/python/.env.example to .env and add your key.\n"
                "Get a key at: https://aistudio.google.com/apikey"
            )

        print("1) Calling Gemini API...")
        try:
            gemini_response = call_gemini(args.gemini_key, args.prompt, args.gemini_model)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            extra = ""
            if e.code == 429:
                extra = gemini_quota_help()
            elif e.code == 404:
                extra = (
                    f"\nModel '{args.gemini_model}' not found or retired.\n"
                    "Set GEMINI_MODEL in .env to a current id, e.g. gemini-2.5-flash-lite\n"
                    "Run: python test_gemini.py --list-models"
                )
            sys.exit(f"Gemini API error {e.code}: {body}{extra}")
        except urllib.error.URLError as e:
            sys.exit(f"Gemini network error: {e.reason}")

        usage = gemini_response.get("usageMetadata") or {}
        input_tokens = int(usage.get("promptTokenCount", 0))
        output_tokens = int(usage.get("candidatesTokenCount", 0))
        total_tokens = int(usage.get("totalTokenCount", input_tokens + output_tokens))

        text = ""
        try:
            text = gemini_response["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError):
            text = "(no text in response)"

        print(f"   Gemini reply: {text.strip()}")
        print(f"   Tokens — input: {input_tokens}, output: {output_tokens}, total: {total_tokens}")

    print(f"\n2) Reporting to PromptPenny at {args.prompt_penny_url}...")
    try:
        record = report_to_prompt_penny(
            base_url=args.prompt_penny_url,
            api_key=args.prompt_penny_key,
            model=prompt_penny_model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            source=args.source,
            metadata={
                "gemini_model": args.gemini_model,
                "prompt_preview": args.prompt[:120],
                "prompt_penny_only": args.prompt_penny_only,
            },
        )
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        sys.exit(f"PromptPenny error {e.code}: {body}")
    except urllib.error.URLError as e:
        sys.exit(
            f"PromptPenny unreachable: {e.reason}\n"
            "Ensure PromptPenny is open, Integration → Enable API Server is ON,\n"
            "and your PC is on the same Wi-Fi as the phone."
        )

    print("\n3) Success! PromptPenny recorded:")
    print(json.dumps(record, indent=2))
    print(f"\n   Cost: ${record.get('cost_usd', 0):.6f}")
    print("   Check Dashboard and History in the PromptPenny app.")


if __name__ == "__main__":
    main()
