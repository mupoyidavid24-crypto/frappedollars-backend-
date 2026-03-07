-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Removed misplaced/incomplete lines from top
-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enum for User Roles (check if types exist or ignore error)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMIN', 'MASTER', 'CLIENT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE sub_status AS ENUM ('ACTIVE', 'EXPIRED', 'SUSPENDED', 'MANUAL_ACTIVE', 'WEEKLY_LIMIT_REACHED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE sub_type AS ENUM ('COPY_TRADING_WEEKLY', 'VPS_MONTHLY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role user_role DEFAULT 'CLIENT',
    is_vip BOOLEAN DEFAULT FALSE,
    needs_vps BOOLEAN DEFAULT FALSE,
    fcm_token TEXT,
    referral_code TEXT UNIQUE,
    referred_by UUID REFERENCES profiles(id),
    total_profit DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- Table definition cleaned up for PostgreSQL

-- 2. TRADING ACCOUNTS
CREATE TABLE IF NOT EXISTS trading_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    mt5_login TEXT NOT NULL,
    mt5_password_encrypted TEXT,
    mt5_server TEXT NOT NULL,
    account_type user_role DEFAULT 'CLIENT',
    balance DECIMAL(15, 2) DEFAULT 0,
    equity DECIMAL(15, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    last_sync TIMESTAMPTZ DEFAULT NOW()
);

-- 3. SUBSCRIPTIONS
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    type sub_type NOT NULL,
    status sub_status DEFAULT 'EXPIRED',
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    auto_renew BOOLEAN DEFAULT TRUE,
    transaction_ref TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. SIGNALS
CREATE TABLE IF NOT EXISTS signals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    master_account_id UUID REFERENCES trading_accounts(id),
    ticket_id_mt5 TEXT NOT NULL,
    symbol TEXT NOT NULL,
    trade_type TEXT NOT NULL,
    volume DECIMAL(10, 2) NOT NULL,
    open_price DECIMAL(15, 5),
    tp DECIMAL(15, 5),
    sl DECIMAL(15, 5),
    status TEXT DEFAULT 'OPEN',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

-- 5. COPIED TRADES
CREATE TABLE IF NOT EXISTS copied_trades (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    signal_id UUID REFERENCES signals(id),
    client_account_id UUID REFERENCES trading_accounts(id),
    client_ticket_id TEXT,
    volume_executed DECIMAL(10, 2),
    execution_status TEXT DEFAULT 'PENDING',
    profit DECIMAL(15, 2) DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

-- 6. SUPPORT TICKETS
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'OPEN',
    admin_response TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. LEARNING CONTENT
CREATE TABLE IF NOT EXISTS learning_content (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    video_url TEXT,
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_trading_accounts_user_id ON trading_accounts(user_id);
-- 8. PAYMENTS (gestion des paiements locaux)
CREATE TABLE IF NOT EXISTS payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client uuid REFERENCES profiles(id),
    montant numeric(12,2) NOT NULL,
    moyen varchar(20) NOT NULL CHECK (moyen IN ('Airtel Money', 'Orange Money')),
    numero varchar(20) NOT NULL,
    preuve text, -- URL Supabase Storage
    statut varchar(20) NOT NULL CHECK (statut IN ('En attente', 'Validé', 'Refusé')) DEFAULT 'En attente',
    date timestamptz NOT NULL DEFAULT now(),
    motif text
);

-- Index pour recherche rapide par statut, moyen, date
CREATE INDEX payments_statut_idx ON payments(statut);
CREATE INDEX payments_moyen_idx ON payments(moyen);
CREATE INDEX payments_date_idx ON payments(date);
-- Table pour journaliser les accès admin
CREATE TABLE IF NOT EXISTS admin_access_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username text NOT NULL,
    access_time timestamptz NOT NULL DEFAULT now(),
    ip text
);
CREATE INDEX admin_access_logs_time_idx ON admin_access_logs(access_time);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_copied_trades_signal_id ON copied_trades(signal_id);

-- Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_content ENABLE ROW LEVEL SECURITY;

-- Policies
-- Profiles: View and Update own
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Trading Accounts: View own
DROP POLICY IF EXISTS "Users can view own accounts" ON trading_accounts;
CREATE POLICY "Users can view own accounts" ON trading_accounts FOR SELECT USING (auth.uid() = user_id);

-- Subscriptions: View own
DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscriptions;
CREATE POLICY "Users can view own subscriptions" ON subscriptions FOR SELECT USING (auth.uid() = user_id);

-- Support Tickets: All actions for own
DROP POLICY IF EXISTS "Users can manage own support tickets" ON support_tickets;
CREATE POLICY "Users can manage own support tickets" ON support_tickets FOR ALL USING (auth.uid() = user_id);

-- Learning Content: Everyone can view
DROP POLICY IF EXISTS "Everyone can view learning content" ON learning_content;
CREATE POLICY "Everyone can view learning content" ON learning_content FOR SELECT USING (true);

-- Auth Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, is_vip, referral_code)
  VALUES (
    new.id,
    new.email,
    'CLIENT',
    (new.email IN (
      'mupoyidavid24@gmail.com',
      'emmanuelwondo07@gmail.com',
      'chanelmimpiya1@gmail.com',
      'claudemenji3@gmail.com',
      'junioryamba86@gmail.com',
      'kwetemuanaezechiasmuzechsong93@gmail.com'
    )),
    upper(substring(md5(random()::text) from 1 for 8))
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
