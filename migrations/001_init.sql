-- migrations/001_init.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE direction AS ENUM ('LONG', 'SHORT');
CREATE TYPE confidence AS ENUM ('NUCLEAR', 'EXTREME', 'SOLID', 'SPECULATIVE', 'WEAK');
CREATE TYPE worker_mode AS ENUM ('MANUAL', 'HYBRID', 'AUTO');
CREATE TYPE trade_status AS ENUM ('OPEN', 'CLOSED_WIN', 'CLOSED_LOSS', 'CLOSED_BE');

CREATE TABLE signals (
    id BIGSERIAL PRIMARY KEY,
    signal_id UUID UNIQUE DEFAULT uuid_generate_v4(),
    timestamp BIGINT NOT NULL,
    symbol TEXT NOT NULL,
    direction direction NOT NULL,
    confidence confidence NOT NULL,
    entry_price DECIMAL(20,8) NOT NULL,
    target_price DECIMAL(20,8) NOT NULL,
    stop_loss DECIMAL(20,8) NOT NULL,
    percent_pnl DECIMAL(8,4),
    rr_ratio DECIMAL(6,2),
    leverage INTEGER NOT NULL,
    confluence TEXT[],
    bybit_link TEXT,
    bybit_deep TEXT,
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    claimed BOOLEAN DEFAULT FALSE,
    claimed_by_worker_id BIGINT,
    claimed_at TIMESTAMPTZ
);

CREATE TABLE sessions (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE workers (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT REFERENCES sessions(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mode worker_mode NOT NULL DEFAULT 'HYBRID',
    starting_capital DECIMAL(20,8) NOT NULL,
    current_balance DECIMAL(20,8) NOT NULL,
    compounding_percent INTEGER NOT NULL DEFAULT 100 CHECK (compounding_percent >= 0 AND compounding_percent <= 100),
    profit_threshold DECIMAL(20,8) DEFAULT 0,
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    total_long INTEGER DEFAULT 0,
    total_short INTEGER DEFAULT 0,
    total_duration_seconds BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE trades (
    id BIGSERIAL PRIMARY KEY,
    worker_id BIGINT REFERENCES workers(id) ON DELETE CASCADE,
    signal_id BIGINT REFERENCES signals(id),
    symbol TEXT NOT NULL,
    direction direction NOT NULL,
    entry_price DECIMAL(20,8) NOT NULL,
    exit_price DECIMAL(20,8),
    quantity DECIMAL(20,8) NOT NULL,
    leverage INTEGER NOT NULL,
    status trade_status NOT NULL DEFAULT 'OPEN',
    pnl_usd DECIMAL(20,8),
    pnl_percent DECIMAL(8,4),
    entry_time TIMESTAMPTZ DEFAULT NOW(),
    exit_time TIMESTAMPTZ,
    exchange TEXT NOT NULL,
    exchange_order_id TEXT,
    UNIQUE(worker_id, symbol, status) -- No duplicate open positions per worker
);

CREATE INDEX idx_signals_timestamp ON signals(timestamp DESC);
CREATE INDEX idx_signals_unclaimed ON signals(claimed, timestamp DESC) WHERE claimed = FALSE;
CREATE INDEX idx_trades_worker ON trades(worker_id);
CREATE INDEX idx_trades_open ON trades(status) WHERE status = 'OPEN';