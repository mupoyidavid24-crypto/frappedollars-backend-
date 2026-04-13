from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import os
import secrets
import sqlite3
from threading import Lock
from typing import Any, Generator
from uuid import uuid4

from backend.trade_identity import build_trade_identity


MAX_DISPATCH_RETRIES = int(os.getenv("MAX_DISPATCH_RETRIES", "10"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def hash_api_key(api_key: str) -> str:
    return hashlib.sha256(api_key.encode("utf-8")).hexdigest()


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

        CREATE INDEX IF NOT EXISTS idx_trade_dispatches_client_status_created
            ON trade_dispatches(client_login, status, created_at);
        """
        with self.connection() as conn:
            conn.executescript(schema)
            self._ensure_column(conn, "trade_dispatches", "normalized_trade_id", "TEXT")
            self._ensure_column(conn, "trade_dispatches", "trade_tag", "TEXT")
            self._ensure_column(conn, "trade_dispatches", "tag_namespace", "INTEGER NOT NULL DEFAULT 1")
            self._ensure_column(conn, "trade_dispatches", "magic_number", "INTEGER")
            self._ensure_column(conn, "trade_dispatches", "broker_comment", "TEXT")

    def _ensure_column(self, conn: sqlite3.Connection, table_name: str, column_name: str, column_def: str) -> None:
        rows = conn.execute(f"PRAGMA table_info({table_name})").fetchall()
        existing_columns = {row[1] for row in rows}
        if column_name not in existing_columns:
            conn.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_def}")

    def issue_api_key(self, mt5_login: str, account_role: str) -> dict[str, str]:
        plain_api_key = secrets.token_urlsafe(32)
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
        with self.connection() as conn:
            row = conn.execute(
                "SELECT mt5_login, account_role, api_key_hash, is_active FROM ea_api_keys WHERE mt5_login = ? LIMIT 1",
                (mt5_login,),
            ).fetchone()
        return dict(row) if row is not None else None

    def get_dispatch_by_dedupe(self, client_login: str, ticket_id: str, action: str) -> dict[str, Any] | None:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM trade_dispatches WHERE client_login = ? AND ticket_id = ? AND action = ? LIMIT 1",
                (client_login, ticket_id, action),
            ).fetchone()
        return dict(row) if row is not None else None

    def create_dispatch(self, payload: dict[str, Any]) -> dict[str, Any]:
        now = utc_now()
        trade_id = payload.get("id", str(uuid4()))
        identity = build_trade_identity(trade_id)
        record = {
            "id": trade_id,
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
            "status": "PENDING",
            "retry_count": 0,
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
        with self._lock, self.connection() as conn:
            conn.execute(
                """
                INSERT INTO trade_dispatches (
                    id, master_login, client_login, ticket_id, action, symbol, trade_type,
                    volume, open_price, sl, tp, status, retry_count, normalized_trade_id,
                    trade_tag, tag_namespace, magic_number, broker_comment, client_ticket_id,
                    last_error, created_at, updated_at, dispatched_at, executed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["id"],
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
        return record

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