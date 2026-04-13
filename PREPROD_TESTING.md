# Preprod Test Plan

This repository already exposes the endpoints needed for a small real-world preproduction run:

- `GET /ping`
- `POST /admin/generate_api_key`
- `POST /master/trade`
- `GET /client/pending_trades/{mt5_login}`
- `POST /client/trade_executed`
- `GET /monitoring`
- `GET /admin/trade_dispatches`

## Goal

Validate the full copy-trading path with up to 10 clients:

1. backend and SQLite persistence are stable
2. each client login has a valid API key
3. each client EA can authenticate and poll without error
4. master trade creation reaches the backend
5. client dispatch and execution are visible in logs

## Provision 10 clients

Use the helper script:

```bash
python scripts/preprod_10_clients.py \
  --admin-key <ADMIN_API_KEY> \
  --master-login 6048965 \
  --client-login <CLIENT_LOGIN_1> \
  --client-login <CLIENT_LOGIN_2> \
  --client-login <CLIENT_LOGIN_3> \
  --client-login <CLIENT_LOGIN_4> \
  --client-login <CLIENT_LOGIN_5> \
  --client-login <CLIENT_LOGIN_6> \
  --client-login <CLIENT_LOGIN_7> \
  --client-login <CLIENT_LOGIN_8> \
  --client-login <CLIENT_LOGIN_9> \
  --client-login <CLIENT_LOGIN_10> \
  --output preprod-report.json
```

The script will:

- verify `GET /ping`
- issue one master API key
- issue up to 10 client API keys
- call `GET /client/pending_trades/{mt5_login}` for each client
- print a compact report

## What to watch in logs

Backend stdout now prints minimal markers for the flow:

- `[API_KEY]` when a key is issued
- `[MASTER_TRADE]` when a trade is created or deduplicated
- `[CLIENT_PULL]` when a client polls the queue
- `[CLIENT_ACK]` when the client reports execution or failure

MT5 client logs already print:

- auth status
- JSON envelope and item count
- execution result
- ACK result

## Run order

1. Start backend with the production database and stable environment variables.
2. Run the helper script above and confirm all clients authenticate.
3. Load each EA client with the right `InpApiKey`.
4. Send one small trade from the master.
5. Verify:
   - master dispatch created
   - client receives `200`
   - one client executes
   - backend stores `EXECUTED`

## Notes

- No new product feature is required for this phase.
- If a client fails, check the exact MT5-derived `client_id` string before regenerating its API key.
- Keep the test volume tiny and use the demo environment before switching to live.
