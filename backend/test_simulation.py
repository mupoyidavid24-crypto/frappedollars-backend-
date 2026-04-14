import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests


ROOT_DIR = Path(__file__).resolve().parent.parent
BACKEND_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8010")
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY", "local-admin-key")
MASTER_LOGIN = os.getenv("MASTER_LOGIN", "6048965")
CLIENT_LOGIN = os.getenv("CLIENT_LOGIN", "32048608_Deriv.com Limited _Deriv-Demo_DEMO")
CLIENT_LOGIN_2 = os.getenv("CLIENT_LOGIN_2", "32048609_Deriv.com Limited _Deriv-Demo_DEMO")
SQLITE_DB_PATH = ROOT_DIR / "backend" / "runtime" / "pipeline-demo.db"
DISPATCH_LEASE_SECONDS = os.getenv("DISPATCH_LEASE_SECONDS", "1")


def _headers(**extra: str) -> dict[str, str]:
    headers = {"x-admin-key": ADMIN_API_KEY}
    headers.update(extra)
    return headers


def _wait_until_ready() -> None:
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            response = requests.get(f"{BACKEND_URL}/ping", timeout=1)
            if response.status_code == 200:
                return
        except requests.RequestException:
            time.sleep(0.25)
    raise RuntimeError("Le backend local ne repond pas sur /ping.")


def _start_server() -> subprocess.Popen[str]:
    env = os.environ.copy()
    env["ADMIN_API_KEY"] = ADMIN_API_KEY
    env["SQLITE_DB_PATH"] = str(SQLITE_DB_PATH)
    env["DISPATCH_LEASE_SECONDS"] = DISPATCH_LEASE_SECONDS
    return subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "backend.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            "8010",
        ],
        cwd=ROOT_DIR,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def _stop_server(process: subprocess.Popen[str]) -> str:
    process.terminate()
    try:
        output, _ = process.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        output, _ = process.communicate(timeout=10)
    return output


def _generate_key(mt5_login: str, role: str) -> str:
    response = requests.post(
        f"{BACKEND_URL}/admin/generate_api_key",
        json={"mt5_login": mt5_login, "account_role": role},
        headers=_headers(),
        timeout=10,
    )
    response.raise_for_status()
    return response.json()["api_key"]


def _admin_list(client_login: str) -> list[dict]:
    response = requests.get(
        f"{BACKEND_URL}/admin/trade_dispatches",
        params={"client_login": client_login},
        headers=_headers(),
        timeout=10,
    )
    response.raise_for_status()
    return response.json()["items"]


def _push_trade(master_key: str, ticket_id: str) -> requests.Response:
    payload = {
        "master_login": MASTER_LOGIN,
        "ticket_id": ticket_id,
        "action": "OPEN",
        "symbol": "EURUSD",
        "trade_type": "BUY",
        "volume": 0.01,
        "open_price": 1.16134,
        "sl": None,
        "tp": None,
    }
    response = requests.post(
        f"{BACKEND_URL}/master/trade",
        json=payload,
        headers={"x-api-key": master_key},
        timeout=10,
    )
    response.raise_for_status()
    return response


def _pull_once(client_key: str) -> dict:
    response = requests.get(
        f"{BACKEND_URL}/client/pending_trades/{CLIENT_LOGIN}",
        headers={"x-api-key": client_key},
        timeout=10,
    )
    response.raise_for_status()
    return response.json()


def _execute_trade(client_key: str, trade_id: str, client_ticket_id: str) -> dict:
    response = requests.post(
        f"{BACKEND_URL}/client/trade_executed",
        json={
            "client_login": CLIENT_LOGIN,
            "trade_id": trade_id,
            "client_ticket_id": client_ticket_id,
        },
        headers={"x-api-key": client_key},
        timeout=10,
    )
    response.raise_for_status()
    return response.json()


def run_demo() -> None:
    if SQLITE_DB_PATH.exists():
        SQLITE_DB_PATH.unlink()

    server = _start_server()
    try:
        _wait_until_ready()
        master_key = _generate_key(MASTER_LOGIN, "MASTER")
        client_key = _generate_key(CLIENT_LOGIN, "CLIENT")
        client_key_2 = _generate_key(CLIENT_LOGIN_2, "CLIENT")

        ticket_id = f"demo-{int(time.time())}"

        print("1. POST /master/trade en broadcast")
        create_response = _push_trade(master_key, ticket_id)
        print(create_response.status_code, create_response.json())

        print("\n2. Etat persiste pour chaque client actif")
        persisted_client_1 = _admin_list(CLIENT_LOGIN)
        persisted_client_2 = _admin_list(CLIENT_LOGIN_2)
        print(persisted_client_1)
        print(persisted_client_2)
        assert len(persisted_client_1) == 1
        assert len(persisted_client_2) == 1
        assert persisted_client_1[0]["status"] == "PENDING"
        assert persisted_client_2[0]["status"] == "PENDING"

        print("\n3. GET /client/pending_trades pour les deux clients")
        pull_response = requests.get(
            f"{BACKEND_URL}/client/pending_trades/{CLIENT_LOGIN}",
            headers={"x-api-key": client_key},
            timeout=10,
        )
        print(pull_response.status_code, pull_response.json())
        pull_response.raise_for_status()
        pull_payload = pull_response.json()
        assert pull_payload["version"] == "v1"
        items = pull_payload["items"]
        assert len(items) == 1
        trade_id = items[0]["id"]

        pull_response_2 = requests.get(
            f"{BACKEND_URL}/client/pending_trades/{CLIENT_LOGIN_2}",
            headers={"x-api-key": client_key_2},
            timeout=10,
        )
        print(pull_response_2.status_code, pull_response_2.json())
        pull_response_2.raise_for_status()
        pull_payload_2 = pull_response_2.json()
        assert pull_payload_2["version"] == "v1"
        assert len(pull_payload_2["items"]) == 1
        trade_id_2 = pull_payload_2["items"][0]["id"]

        second_pull = requests.get(
            f"{BACKEND_URL}/client/pending_trades/{CLIENT_LOGIN}",
            headers={"x-api-key": client_key},
            timeout=10,
        )
        print(second_pull.status_code, second_pull.json())
        second_pull.raise_for_status()
        second_payload = second_pull.json()
        assert second_payload["version"] == "v1"
        assert second_payload["items"] == []

        second_pull_2 = requests.get(
            f"{BACKEND_URL}/client/pending_trades/{CLIENT_LOGIN_2}",
            headers={"x-api-key": client_key_2},
            timeout=10,
        )
        print(second_pull_2.status_code, second_pull_2.json())
        second_pull_2.raise_for_status()
        second_payload_2 = second_pull_2.json()
        assert second_payload_2["version"] == "v1"
        assert second_payload_2["items"] == []

        print("\n4. Redemarrage serveur puis verification de persistance")
        print(_stop_server(server))
        server = _start_server()
        _wait_until_ready()

        after_restart = _admin_list(CLIENT_LOGIN)
        after_restart_2 = _admin_list(CLIENT_LOGIN_2)
        print(after_restart)
        print(after_restart_2)
        assert len(after_restart) == 1
        assert len(after_restart_2) == 1
        assert after_restart[0]["id"] == trade_id
        assert after_restart_2[0]["id"] == trade_id_2
        assert after_restart[0]["status"] == "DISPATCHED"
        assert after_restart_2[0]["status"] == "DISPATCHED"

        print("\n5. POST /client/trade_executed pour les deux clients")
        execute_response = requests.post(
            f"{BACKEND_URL}/client/trade_executed",
            json={
                "client_login": CLIENT_LOGIN,
                "trade_id": trade_id,
                "client_ticket_id": "mt5-local-ticket-1",
            },
            headers={"x-api-key": client_key},
            timeout=10,
        )
        print(execute_response.status_code, execute_response.json())
        execute_response.raise_for_status()

        execute_response_2 = requests.post(
            f"{BACKEND_URL}/client/trade_executed",
            json={
                "client_login": CLIENT_LOGIN_2,
                "trade_id": trade_id_2,
                "client_ticket_id": "mt5-local-ticket-2",
            },
            headers={"x-api-key": client_key_2},
            timeout=10,
        )
        print(execute_response_2.status_code, execute_response_2.json())
        execute_response_2.raise_for_status()

        print("\n6. Etat final conserve")
        final_state = _admin_list(CLIENT_LOGIN)
        final_state_2 = _admin_list(CLIENT_LOGIN_2)
        print(final_state)
        print(final_state_2)
        assert len(final_state) == 1
        assert len(final_state_2) == 1
        assert final_state[0]["status"] == "EXECUTED"
        assert final_state_2[0]["status"] == "EXECUTED"
        assert final_state[0]["client_ticket_id"] == "mt5-local-ticket-1"
        assert final_state_2[0]["client_ticket_id"] == "mt5-local-ticket-2"

        print("\n6. Preuve de non double-dispatch en concurrence")
        concurrent_ticket = f"concurrent-{int(time.time())}"
        _push_trade(master_key, concurrent_ticket)
        with ThreadPoolExecutor(max_workers=2) as executor:
            result_a = executor.submit(_pull_once, client_key)
            result_b = executor.submit(_pull_once, client_key)
            payload_a = result_a.result()
            payload_b = result_b.result()
        count_a = len(payload_a["items"])
        count_b = len(payload_b["items"])
        print(payload_a)
        print(payload_b)
        assert sorted([count_a, count_b]) == [0, 1]
        concurrent_items = payload_a["items"] if payload_a["items"] else payload_b["items"]
        concurrent_trade_id = concurrent_items[0]["id"]
        print(_execute_trade(client_key, concurrent_trade_id, "mt5-concurrency-ticket"))

        print("\n7. Preuve de reprise apres crash client")
        retry_ticket = f"retry-{int(time.time())}"
        _push_trade(master_key, retry_ticket)
        first_retry_pull = _pull_once(client_key)
        print(first_retry_pull)
        assert len(first_retry_pull["items"]) == 1
        first_retry_id = first_retry_pull["items"][0]["id"]
        time.sleep(int(DISPATCH_LEASE_SECONDS) + 1)
        second_retry_pull = _pull_once(client_key)
        print(second_retry_pull)
        retry_matches = [item for item in second_retry_pull["items"] if item["id"] == first_retry_id]
        assert len(retry_matches) == 1
        assert retry_matches[0]["retry_count"] == 1

        print("\n8. Preuve d'idempotence sous spam master")
        spam_ticket = f"spam-{int(time.time())}"
        for _ in range(3):
            response = _push_trade(master_key, spam_ticket)
            print(response.json())
        spam_rows = [row for row in _admin_list(CLIENT_LOGIN) if row["ticket_id"] == spam_ticket]
        print(spam_rows)
        assert len(spam_rows) == 1

        print("\nDEMO_OK_HARDENED")
    finally:
        if server.poll() is None:
            print(_stop_server(server))


if __name__ == "__main__":
    run_demo()
