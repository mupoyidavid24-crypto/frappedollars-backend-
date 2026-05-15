BEGIN;

CREATE TABLE IF NOT EXISTS business_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    currency TEXT NOT NULL DEFAULT 'USD',
    copy_trading_weekly_price NUMERIC(12, 2) NOT NULL DEFAULT 50,
    vps_monthly_price NUMERIC(12, 2) NOT NULL DEFAULT 30,
    weekly_profit_limit NUMERIC(12, 2) NOT NULL DEFAULT 120,
    weekly_profit_limit_nature TEXT NOT NULL DEFAULT 'technical_limit',
    weekly_profit_limit_description TEXT NOT NULL DEFAULT 'Limite technique de protection: la copie s''arrete automatiquement lorsque le profit hebdomadaire atteint 120 USD.',
    minimum_capital_required NUMERIC(12, 2) NOT NULL DEFAULT 30,
    subscription_payment_window_weekdays JSONB NOT NULL DEFAULT '[5, 6]'::jsonb,
    updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_business_rules_updated_at ON business_rules(updated_at DESC);

CREATE TABLE IF NOT EXISTS payment_methods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    provider TEXT NOT NULL,
    label TEXT NOT NULL,
    account_name TEXT,
    account_number TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_is_active ON payment_methods(is_active);

CREATE TABLE IF NOT EXISTS vps_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
    status TEXT NOT NULL DEFAULT 'DISCONNECTED' CHECK (status IN ('DISCONNECTED', 'CONNECTED', 'RESTART_REQUESTED', 'ERROR')),
    provider TEXT,
    host_label TEXT,
    notes TEXT,
    last_heartbeat TIMESTAMPTZ,
    last_restart_requested_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vps_assignments_status ON vps_assignments(status);
CREATE INDEX IF NOT EXISTS idx_vps_assignments_updated_at ON vps_assignments(updated_at DESC);

CREATE OR REPLACE FUNCTION set_business_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_business_rules_updated_at ON business_rules;
CREATE TRIGGER trg_business_rules_updated_at
    BEFORE UPDATE ON business_rules
    FOR EACH ROW EXECUTE FUNCTION set_business_rules_updated_at();

DROP TRIGGER IF EXISTS trg_payment_methods_updated_at ON payment_methods;
CREATE TRIGGER trg_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION set_business_rules_updated_at();

DROP TRIGGER IF EXISTS trg_vps_assignments_updated_at ON vps_assignments;
CREATE TRIGGER trg_vps_assignments_updated_at
    BEFORE UPDATE ON vps_assignments
    FOR EACH ROW EXECUTE FUNCTION set_business_rules_updated_at();

INSERT INTO business_rules (
    currency,
    copy_trading_weekly_price,
    vps_monthly_price,
    weekly_profit_limit,
    weekly_profit_limit_nature,
    weekly_profit_limit_description,
    minimum_capital_required,
    subscription_payment_window_weekdays
)
SELECT
    'USD',
    50,
    30,
    120,
    'technical_limit',
    'Limite technique de protection: la copie s''arrete automatiquement lorsque le profit hebdomadaire atteint 120 USD.',
    30,
    '[5, 6]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM business_rules);

COMMIT;
