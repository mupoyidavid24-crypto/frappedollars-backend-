from __future__ import annotations

from contextlib import contextmanager
import base64
from datetime import datetime, timedelta, timezone
import hmac
import hashlib
import os
import sqlite3
from threading import Lock
from typing import Any, Generator
from uuid import uuid4

from backend.trade_identity import build_trade_identity


MAX_DISPATCH_RETRIES = int(os.getenv("MAX_DISPATCH_RETRIES", "10"))
API_KEY_SECRET = os.getenv("API_KEY_SECRET", os.getenv("ADMIN_API_KEY", "frappedollars-api-key-seed"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def hash_api_key(api_key: str) -> str:
    return hashlib.sha256(api_key.encode("utf-8")).hexdigest()


def derive_api_key(mt5_login: str, account_role: str) -> str:
    mt5_login = mt5_login.strip()
    account_role = account_role.strip().upper()
    digest = hmac.new(
        API_KEY_SECRET.encode("utf-8"),
        f"{mt5_login}:{account_role}".encode("utf-8"),
        hashlib.sha256,
    ).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


class SQLiteStorage:
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        self._lock = Lock()
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._initialize()

    @contextmanager
    def connection(self) -> Generator[sqlite3.Connection, None, None]:
        connection = sqlite3.connect(self.db_path, timeout=30, isolation_level=None)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
        finally:
            connection.close()

    def _initialize(self) -> None:
        schema = """
        PRAGMA journal_mode=WAL;

        CREATE TABLE IF NOT EXISTS ea_api_keys (
            mt5_login TEXT PRIMARY KEY,
            account_role TEXT NOT NULL CHECK (account_role IN ('MASTER', 'CLIENT')),
            api_key_hash TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS trade_dispatches (
            id TEXT PRIMARY KEY,
            signal_id TEXT,
            master_login TEXT NOT NULL,
            client_login TEXT NOT NULL,
            ticket_id TEXT NOT NULL,
            action TEXT NOT NULL CHECK (action IN ('OPEN', 'CLOSE')),
            symbol TEXT NOT NULL,
            trade_type TEXT NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
            volume REAL NOT NULL,
            open_price REAL,
            sl REAL,
            tp REAL,
            status TEXT NOT NULL CHECK (status IN ('PENDING', 'DISPATCHED', 'EXECUTED', 'FAILED', 'RETRY', 'CANCELLED')),
            retry_count INTEGER NOT NULL DEFAULT 0,
            normalized_trade_id TEXT,
            trade_tag TEXT,
            tag_namespace INTEGER NOT NULL DEFAULT 1,
            magic_number INTEGER,
            broker_comment TEXT,
            client_ticket_id TEXT,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            dispatched_at TEXT,
            executed_at TEXT,
            UNIQUE (client_login, ticket_id, action)
        );

        CREATE TABLE IF NOT EXISTS master_trade_signals (
            id TEXT PRIMARY KEY,
            master_login TEXT NOT NULL,
            ticket_id TEXT NOT NULL,
            action TEXT NOT NULL CHECK (action IN ('OPEN', 'CLOSE')),
            symbol TEXT NOT NULL,
            trade_type TEXT NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
            volume REAL NOT NULL,
            open_price REAL,
            sl REAL,
            tp REAL,
            normalized_trade_id TEXT NOT NULL,
            trade_tag TEXT NOT NULL,
            tag_namespace INTEGER NOT NULL DEFAULT 1,
            magic_number INTEGER NOT NULL,
            broker_comment TEXT NOT NULL,
            status TEXT NOT NULL CHECK (status IN ('CREATED', 'DISPATCHED', 'CANCELLED')),
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (master_login, ticket_id, action)
        );

        CREATE TABLE IF NOT EXISTS client_subscriptions (
            mt5_login TEXT PRIMARY KEY,
            plan_code TEXT,
            status TEXT NOT NULL CHECK (status IN ('TRIAL', 'ACTIVE', 'PAUSED', 'CANCELLED')),
            starts_at TEXT,
            ends_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (mt5_login) REFERENCES ea_api_keys (mt5_login) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS admin_accounts (
            username TEXT PRIMARY KEY,
            password_hash TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_trade_dispatches_client_status_created
            ON trade_dispatches(client_login, status, created_at);
        CREATE INDEX IF NOT EXISTS idx_trade_dispatches_signal_status_created
            ON trade_dispatches(signal_id, status, created_at);
        CREATE INDEX IF NOT EXISTS idx_master_trade_signals_master_status_created
            ON master_trade_signals(master_login, status, created_at);
        """
        with self.connection() as conn:
            conn.executescript(schema)
            self._ensure_column(conn, "trade_dispatches", "signal_id", "TEXT")
            self._ensure_column(conn, "trade_dispatches", "normalized_trade_id", "TEXT")
            self._ensure_column(conn, "trade_dispatches", "trade_tag", "TEXT")
            self._ensure_column(conn, "trade_dispatches", "tag_namespace", "INTEGER NOT NULL DEFAULT 1")
            self._ensure_column(conn, "trade_dispatches", "magic_number", "INTEGER")
            self._ensure_column(conn, "trade_dispatches", "broker_comment", "TEXT")

    def _hash_admin_password(self, password: str) -> str:
        return hashlib.sha256(password.encode("utf-8")).hexdigest()

    def upsert_admin_account(self, username: str, password: str) -> dict[str, str]:
        now = utc_now()
        password_hash = self._hash_admin_password(password)
        with self._lock, self.connection() as conn:
            conn.execute(
                """
                INSERT INTO admin_accounts (username, password_hash, is_active, created_at, updated_at)
                VALUES (?, ?, 1, ?, ?)
                ON CONFLICT(username) DO UPDATE SET
                    password_hash=excluded.password_hash,
                    is_active=1,
                    updated_at=excluded.updated_at
                """,
                (username, password_hash, now, now),
            )
        return {"username": username, "created_at": now}

    def get_admin_account(self, username: str) -> dict[str, Any] | None:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT username, password_hash, is_active FROM admin_accounts WHERE username = ? LIMIT 1",
                (username,),
            ).fetchone()
        return dict(row) if row is not None else None

    def verify_admin_credentials(self, username: str, password: str) -> bool:
        record = self.get_admin_account(username)
        if record is None or not bool(record.get("is_active", 0)):
            return False
        expected_hash = record.get("password_hash", "")
        return hmac.compare_digest(expected_hash, self._hash_admin_password(password))

    def _ensure_column(self, conn: sqlite3.Connection, table_name: str, column_name: str, column_def: str) -> None:
        rows = conn.execute(f"PRAGMA table_info({table_name})").fetchall()
        existing_columns = {row[1] for row in rows}
        if column_name not in existing_columns:
            conn.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_def}")

    def issue_api_key(self, mt5_login: str, account_role: str) -> dict[str, str]:
        mt5_login = mt5_login.strip()
        account_role = account_role.strip().upper()
        plain_api_key = derive_api_key(mt5_login, account_role)
        now = utc_now()
        with self._lock, self.connection() as conn:
            conn.execute(
                """
                INSERT INTO ea_api_keys (mt5_login, account_role, api_key_hash, is_active, created_at, updated_at)
                VALUES (?, ?, ?, 1, ?, ?)
                ON CONFLICT(mt5_login) DO UPDATE SET
                    account_role=excluded.account_role,
                    api_key_hash=excluded.api_key_hash,
                    is_active=1,
                    updated_at=excluded.updated_at
                """,
                (mt5_login, account_role, hash_api_key(plain_api_key), now, now),
            )
        return {"mt5_login": mt5_login, "account_role": account_role, "api_key": plain_api_key}

    def get_api_key_record(self, mt5_login: str) -> dict[str, Any] | None:
        mt5_login = mt5_login.strip()
        with self.connection() as conn:
            row = conn.execute(
                "SELECT mt5_login, account_role, api_key_hash, is_active FROM ea_api_keys WHERE mt5_login = ? LIMIT 1",
                (mt5_login,),
            ).fetchone()
        return dict(row) if row is not None else None

    def list_active_client_logins(self) -> list[str]:
        with self.connection() as conn:
            rows = conn.execute(
                "SELECT mt5_login FROM ea_api_keys WHERE account_role = 'CLIENT' AND is_active = 1 ORDER BY created_at ASC"
            ).fetchall()
        return [row["mt5_login"] for row in rows]

    def get_signal_by_dedupe(self, master_login: str, ticket_id: str, action: str) -> dict[str, Any] | None:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM master_trade_signals WHERE master_login = ? AND ticket_id = ? AND action = ? LIMIT 1",
                (master_login, ticket_id, action),
            ).fetchone()
        return dict(row) if row is not None else None

    def _build_signal_record(self, payload: dict[str, Any]) -> dict[str, Any]:
        signal_id = payload.get("id", str(uuid4()))
        identity = build_trade_identity(signal_id)
        now = utc_now()
        return {
            "id": signal_id,
            "master_login": payload["master_login"],
            "ticket_id": payload["ticket_id"],
            "action": payload["action"],
            "symbol": payload["symbol"],
            "trade_type": payload["trade_type"],
            "volume": payload["volume"],
            "open_price": payload.get("open_price"),
            "sl": payload.get("sl"),
            "tp": payload.get("tp"),
            "normalized_trade_id": identity["normalized_trade_id"],
            "trade_tag": identity["trade_tag"],
            "tag_namespace": identity["tag_namespace"],
            "magic_number": identity["magic_number"],
            "broker_comment": identity["broker_comment"],
            "status": payload.get("status", "CREATED"),
            "created_at": now,
            "updated_at": now,
        }

    def create_master_trade_signal(self, payload: dict[str, Any]) -> dict[str, Any]:
        record = self._build_signal_record(payload)
        with self._lock, self.connection() as conn:
            conn.execute(
                """
                INSERT INTO master_trade_signals (
                    id, master_login, ticket_id, action, symbol, trade_type, volume,
                    open_price, sl, tp, normalized_trade_id, trade_tag, tag_namespace,
                    magic_number, broker_comment, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["id"],
                    record["master_login"],
                    record["ticket_id"],
                    record["action"],
                    record["symbol"],
                    record["trade_type"],
                    record["volume"],
                    record["open_price"],
                    record["sl"],
                    record["tp"],
                    record["normalized_trade_id"],
                    record["trade_tag"],
                    record["tag_namespace"],
                    record["magic_number"],
                    record["broker_comment"],
                    record["status"],
                    record["created_at"],
                    record["updated_at"],
                ),
            )
        return record

    def _get_signal_by_dedupe_in_connection(
        self,
        conn: sqlite3.Connection,
        master_login: str,
        ticket_id: str,
        action: str,
    ) -> dict[str, Any] | None:
        row = conn.execute(
            "SELECT * FROM master_trade_signals WHERE master_login = ? AND ticket_id = ? AND action = ? LIMIT 1",
            (master_login, ticket_id, action),
        ).fetchone()
        return dict(row) if row is not None else None

    def create_and_fanout_master_trade_signal(self, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock, self.connection() as conn:
            conn.execute("BEGIN IMMEDIATE")

            existing = self._get_signal_by_dedupe_in_connection(
                conn,
                payload["master_login"],
                payload["ticket_id"],
                payload["action"],
            )
            if existing is not None:
                conn.commit()
                return {"signal": existing, "dispatches": [], "duplicate": True}

            signal = self._build_signal_record(payload)
            conn.execute(
                """
                INSERT INTO master_trade_signals (
                    id, master_login, ticket_id, action, symbol, trade_type, volume,
                    open_price, sl, tp, normalized_trade_id, trade_tag, tag_namespace,
                    magic_number, broker_comment, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    signal["id"],
                    signal["master_login"],
                    signal["ticket_id"],
                    signal["action"],
                    signal["symbol"],
                    signal["trade_type"],
                    signal["volume"],
                    signal["open_price"],
                    signal["sl"],
                    signal["tp"],
                    signal["normalized_trade_id"],
                    signal["trade_tag"],
                    signal["tag_namespace"],
                    signal["magic_number"],
                    signal["broker_comment"],
                    signal["status"],
                    signal["created_at"],
                    signal["updated_at"],
                ),
            )

            rows = conn.execute(
                "SELECT mt5_login FROM ea_api_keys WHERE account_role = 'CLIENT' AND is_active = 1 ORDER BY created_at ASC"
            ).fetchall()

            dispatched: list[dict[str, Any]] = []
            now = utc_now()
            for row in rows:
                client_login = row["mt5_login"]
                dispatch_payload = {
                    "signal_id": signal["id"],
                    "master_login": signal["master_login"],
                    "client_login": client_login,
                    "ticket_id": signal["ticket_id"],
                    "action": signal["action"],
                    "symbol": signal["symbol"],
                    "trade_type": signal["trade_type"],
                    "volume": signal["volume"],
                    "open_price": signal.get("open_price"),
                    "sl": signal.get("sl"),
                    "tp": signal.get("tp"),
                    "identity": signal,
                    "status": "PENDING",
                    "created_at": now,
                    "updated_at": now,
                }
                record = self._build_dispatch_record(dispatch_payload)
                dispatched.append(record)

            if dispatched:
                conn.executemany(
                    """
                    INSERT INTO trade_dispatches (
                        id, signal_id, master_login, client_login, ticket_id, action, symbol, trade_type,
                        volume, open_price, sl, tp, status, retry_count, normalized_trade_id,
                        trade_tag, tag_namespace, magic_number, broker_comment, client_ticket_id,
                        last_error, created_at, updated_at, dispatched_at, executed_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        (
                            record["id"],
                            record.get("signal_id"),
                            record["master_login"],
                            record["client_login"],
                            record["ticket_id"],
                            record["action"],
                            record["symbol"],
                            record["trade_type"],
                            record["volume"],
                            record["open_price"],
                            record["sl"],
                            record["tp"],
                            record["status"],
                            record["retry_count"],
                            record["normalized_trade_id"],
                            record["trade_tag"],
                            record["tag_namespace"],
                            record["magic_number"],
                            record["broker_comment"],
                            record["client_ticket_id"],
                            record["last_error"],
                            record["created_at"],
                            record["updated_at"],
                            record["dispatched_at"],
                            record["executed_at"],
                        )
                        for record in dispatched
                    ],
                )

            signal_status = "DISPATCHED" if dispatched else "CREATED"
            conn.execute(
                "UPDATE master_trade_signals SET status = ?, updated_at = ? WHERE id = ?",
                (signal_status, now, signal["id"]),
            )
            conn.commit()

            signal["status"] = signal_status
            return {"signal": signal, "dispatches": dispatched, "duplicate": False}

    def _build_dispatch_record(self, payload: dict[str, Any]) -> dict[str, Any]:
        trade_id = payload.get("id", str(uuid4()))
        identity = payload.get("identity") or build_trade_identity(trade_id)
        now = utc_now()
        return {
            "id": trade_id,
            "signal_id": payload.get("signal_id"),
            "master_login": payload["master_login"],
            "client_login": payload["client_login"],
            "ticket_id": payload["ticket_id"],
            "action": payload["action"],
            "symbol": payload["symbol"],
            "trade_type": payload["trade_type"],
            "volume": payload["volume"],
            "open_price": payload.get("open_price"),
            "sl": payload.get("sl"),
            "tp": payload.get("tp"),
            "status": payload.get("status", "PENDING"),
            "retry_count": payload.get("retry_count", 0),
            "normalized_trade_id": identity["normalized_trade_id"],
            "trade_tag": identity["trade_tag"],
            "tag_namespace": identity["tag_namespace"],
            "magic_number": identity["magic_number"],
            "broker_comment": identity["broker_comment"],
            "client_ticket_id": None,
            "last_error": None,
            "created_at": now,
            "updated_at": now,
            "dispatched_at": None,
            "executed_at": None,
        }

    def _insert_dispatch_record(self, conn: sqlite3.Connection, record: dict[str, Any]) -> None:
        conn.execute(
            """
            INSERT INTO trade_dispatches (
                id, signal_id, master_login, client_login, ticket_id, action, symbol, trade_type,
                volume, open_price, sl, tp, status, retry_count, normalized_trade_id,
                trade_tag, tag_namespace, magic_number, broker_comment, client_ticket_id,
                last_error, created_at, updated_at, dispatched_at, executed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                record["id"],
                record.get("signal_id"),
                record["master_login"],
                record["client_login"],
                record["ticket_id"],
                record["action"],
                record["symbol"],
                record["trade_type"],
                record["volume"],
                record["open_price"],
                record["sl"],
                record["tp"],
                record["status"],
                record["retry_count"],
                record["normalized_trade_id"],
                record["trade_tag"],
                record["tag_namespace"],
                record["magic_number"],
                record["broker_comment"],
                record["client_ticket_id"],
                record["last_error"],
                record["created_at"],
                record["updated_at"],
                record["dispatched_at"],
                record["executed_at"],
            ),
        )

    def get_dispatch_by_dedupe(self, client_login: str, ticket_id: str, action: str) -> dict[str, Any] | None:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM trade_dispatches WHERE client_login = ? AND ticket_id = ? AND action = ? LIMIT 1",
                (client_login, ticket_id, action),
            ).fetchone()
        return dict(row) if row is not None else None

    def create_dispatch(self, payload: dict[str, Any]) -> dict[str, Any]:
        record = self._build_dispatch_record(payload)
        with self._lock, self.connection() as conn:
            self._insert_dispatch_record(conn, record)
        return record

    def fanout_master_trade_signal(self, signal: dict[str, Any]) -> list[dict[str, Any]]:
        result = self.create_and_fanout_master_trade_signal(signal)
        return result["dispatches"]

    def claim_dispatches(self, client_login: str, limit: int) -> list[dict[str, Any]]:
        with self._lock, self.connection() as conn:
            conn.execute("BEGIN IMMEDIATE")
            rows = conn.execute(
                """
                SELECT id FROM trade_dispatches
                WHERE client_login = ? AND status IN ('PENDING', 'RETRY')
                ORDER BY created_at ASC
                LIMIT ?
                """,
                (client_login, limit),
            ).fetchall()
            if not rows:
                conn.commit()
                return []

            now = utc_now()
            identifiers = [row["id"] for row in rows]
            placeholders = ",".join("?" for _ in identifiers)
            conn.execute(
                f"UPDATE trade_dispatches SET status = 'DISPATCHED', dispatched_at = ?, updated_at = ? WHERE id IN ({placeholders})",
                (now, now, *identifiers),
            )
            claimed = conn.execute(
                f"SELECT * FROM trade_dispatches WHERE id IN ({placeholders}) ORDER BY created_at ASC",
                identifiers,
            ).fetchall()
            conn.commit()
        return [dict(row) for row in claimed]

    def requeue_stale_dispatches(self, client_login: str, lease_timeout_seconds: int) -> int:
        cutoff = (datetime.now(timezone.utc) - timedelta(seconds=lease_timeout_seconds)).isoformat()
        with self._lock, self.connection() as conn:
            conn.execute("BEGIN IMMEDIATE")
            rows = conn.execute(
                """
                SELECT id, retry_count
                FROM trade_dispatches
                WHERE client_login = ?
                  AND status = 'DISPATCHED'
                  AND dispatched_at IS NOT NULL
                  AND dispatched_at <= ?
                ORDER BY created_at ASC
                """,
                (client_login, cutoff),
            ).fetchall()

            affected = 0
            now = utc_now()
            for row in rows:
                trade_id = row["id"]
                next_retry_count = int(row["retry_count"]) + 1
                if next_retry_count >= MAX_DISPATCH_RETRIES:
                    conn.execute(
                        """
                        UPDATE trade_dispatches
                        SET status = 'CANCELLED',
                            last_error = ?,
                            updated_at = ?
                        WHERE id = ?
                        """,
                        (f"Dispatch lease expired after {MAX_DISPATCH_RETRIES} retries", now, trade_id),
                    )
                else:
                    conn.execute(
                        """
                        UPDATE trade_dispatches
                        SET status = 'RETRY',
                            retry_count = retry_count + 1,
                            last_error = 'Dispatch lease expired',
                            updated_at = ?
                        WHERE id = ?
                        """,
                        (now, trade_id),
                    )
                affected += 1
            conn.commit()
        return affected

    def update_dispatch_status(
        self,
        *,
        trade_id: str,
        client_login: str,
        required_status: str,
        updates: dict[str, Any],
    ) -> dict[str, Any] | None:
        with self._lock, self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM trade_dispatches WHERE id = ? AND client_login = ? AND status = ? LIMIT 1",
                (trade_id, client_login, required_status),
            ).fetchone()
            if row is None:
                return None

            merged = dict(row)
            merged.update(updates)
            merged["updated_at"] = utc_now()
            conn.execute(
                """
                UPDATE trade_dispatches
                SET status = ?, retry_count = ?, client_ticket_id = ?, last_error = ?,
                    updated_at = ?, dispatched_at = ?, executed_at = ?
                WHERE id = ?
                """,
                (
                    merged["status"],
                    merged["retry_count"],
                    merged.get("client_ticket_id"),
                    merged.get("last_error"),
                    merged["updated_at"],
                    merged.get("dispatched_at"),
                    merged.get("executed_at"),
                    trade_id,
                ),
            )
            updated = conn.execute(
                "SELECT * FROM trade_dispatches WHERE id = ? LIMIT 1",
                (trade_id,),
            ).fetchone()
        return dict(updated) if updated is not None else None

    def list_dispatches(
        self,
        *,
        client_login: str | None = None,
        status_filter: str | None = None,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        query = "SELECT * FROM trade_dispatches WHERE 1=1"
        params: list[Any] = []
        if client_login:
            query += " AND client_login = ?"
            params.append(client_login)
        if status_filter:
            query += " AND status = ?"
            params.append(status_filter)
        query += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        with self.connection() as conn:
            rows = conn.execute(query, params).fetchall()
        return [dict(row) for row in rows]

    def monitoring_counts(self) -> dict[str, int]:
        with self.connection() as conn:
            rows = conn.execute(
                "SELECT status, COUNT(*) AS count FROM trade_dispatches GROUP BY status"
            ).fetchall()
        return {row["status"]: row["count"] for row in rows}