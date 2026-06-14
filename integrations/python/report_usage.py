#!/usr/bin/env python3
"""Report AI token usage to PromptPenny."""

import argparse
import json
import os
import urllib.request

DEFAULT_URL = "http://127.0.0.1:8765"


def report_usage(
    base_url: str,
    api_key: str,
    model: str,
    input_tokens: int,
    output_tokens: int,
    source: str = "script",
    session_id: str | None = None,
) -> dict:
    url = f"{base_url.rstrip('/')}/api/v1/usage"
    payload = {
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "source": source,
    }
    if session_id:
        payload["session_id"] = session_id

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
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Report usage to PromptPenny")
    parser.add_argument("--url", default=os.environ.get("PROMPT_PENNY_URL", DEFAULT_URL))
    parser.add_argument("--api-key", default=os.environ.get("PROMPT_PENNY_API_KEY", ""))
    parser.add_argument("--model", required=True)
    parser.add_argument("--input", type=int, required=True, dest="input_tokens")
    parser.add_argument("--output", type=int, required=True, dest="output_tokens")
    parser.add_argument("--source", default="python")
    parser.add_argument("--session-id", default=None)
    args = parser.parse_args()

    if not args.api_key:
        raise SystemExit("Set --api-key or PROMPT_PENNY_API_KEY")

    result = report_usage(
        base_url=args.url,
        api_key=args.api_key,
        model=args.model,
        input_tokens=args.input_tokens,
        output_tokens=args.output_tokens,
        source=args.source,
        session_id=args.session_id,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
