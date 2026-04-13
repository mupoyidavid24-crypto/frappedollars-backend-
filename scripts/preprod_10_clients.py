from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

import requests


SESSION = requests.Session()
SESSION.trust_env = False


@dataclass
class ClientReport:
    mt5_login: str
    account_role: str
    api_key: str | None = None
    auth_ok: bool = False
    pending_items: int | None = None
    error: str | None = None


@dataclass
class RunReport:
    backend_url: str
    master_login: str
    master_api_key: str | None = None
    ping_ok: bool = False
    monitoring_ok: bool = False
    clients: list[ClientReport] | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Provision up to 10 preproduction MT5 clients and verify backend access."
    )
    parser.add_argument("--backend-url", default="https://frappedollars-backend-1.onrender.com")
    parser.add_argument("--admin-key", required=True)
    parser.add_argument("--master-login", default="6048965")
    parser.add_argument(
        "--client-login",
        action="append",
        required=True,
        help="MT5 client login to provision. Repeat up to 10 times.",
    )
    parser.add_argument("--output", help="Optional JSON file for the run report.")
    return parser.parse_args()


def admin_headers(admin_key: str) -> dict[str, str]:
    return {"x-admin-key": admin_key}


def api_headers(api_key: str) -> dict[str, str]:
    return {"x-api-key": api_key}


def ping(backend_url: str) -> bool:
    response = SESSION.get(f"{backend_url}/ping", timeout=10)
    response.raise_for_status()
    return True


def issue_key(backend_url: str, admin_key: str, mt5_login: str, role: str) -> str:
    response = SESSION.post(
        f"{backend_url}/admin/generate_api_key",
        headers=admin_headers(admin_key),
        json={"mt5_login": mt5_login, "account_role": role},
        timeout=20,
    )
    response.raise_for_status()
    return response.json()["api_key"]


def list_monitoring(backend_url: str, admin_key: str) -> dict[str, Any]:
    response = SESSION.get(
        f"{backend_url}/monitoring",
        headers=admin_headers(admin_key),
        timeout=20,
    )
    response.raise_for_status()
    return response.json()


def poll_client(backend_url: str, mt5_login: str, api_key: str) -> tuple[bool, int]:
    response = SESSION.get(
        f"{backend_url}/client/pending_trades/{mt5_login}",
        headers=api_headers(api_key),
        timeout=20,
    )
    response.raise_for_status()
    payload = response.json()
    return True, len(payload.get("items", []))


def main() -> int:
    args = parse_args()

    client_logins = [login.strip() for login in args.client_login if login.strip()]
    if len(client_logins) == 0:
        print("Aucun login client fourni.", file=sys.stderr)
        return 2
    if len(client_logins) > 10:
        print("Limite de 10 clients dépassée.", file=sys.stderr)
        return 2

    report = RunReport(
        backend_url=args.backend_url,
        master_login=args.master_login,
        clients=[],
    )

    print(f"[PREPROD] Backend: {args.backend_url}")
    report.ping_ok = ping(args.backend_url)
    print("[PREPROD] /ping OK")

    report.master_api_key = issue_key(args.backend_url, args.admin_key, args.master_login, "MASTER")
    print(f"[PREPROD] MASTER key issued for {args.master_login}")

    monitoring = list_monitoring(args.backend_url, args.admin_key)
    report.monitoring_ok = True
    print(f"[PREPROD] monitoring={json.dumps(monitoring, ensure_ascii=False)}")

    for index, mt5_login in enumerate(client_logins, start=1):
        client_report = ClientReport(mt5_login=mt5_login, account_role="CLIENT")
        try:
            client_report.api_key = issue_key(args.backend_url, args.admin_key, mt5_login, "CLIENT")
            print(f"[PREPROD] ({index}/{len(client_logins)}) CLIENT key issued for {mt5_login}")
            auth_ok, pending_items = poll_client(args.backend_url, mt5_login, client_report.api_key)
            client_report.auth_ok = auth_ok
            client_report.pending_items = pending_items
            print(
                f"[PREPROD] ({index}/{len(client_logins)}) poll OK for {mt5_login} pending_items={pending_items}"
            )
        except Exception as exc:  # noqa: BLE001 - preprod report wants the raw failure
            client_report.error = str(exc)
            print(f"[PREPROD] ({index}/{len(client_logins)}) ERROR {mt5_login}: {exc}")
        report.clients.append(client_report)

    if args.output:
        output_path = Path(args.output)
        output_path.write_text(
            json.dumps(
                {
                    **asdict(report),
                    "clients": [asdict(client) for client in report.clients or []],
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"[PREPROD] report written to {output_path}")

    failed_clients = [client for client in report.clients or [] if not client.auth_ok]
    if failed_clients:
        print("[PREPROD] completed with failures")
        return 1

    print("[PREPROD] completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
