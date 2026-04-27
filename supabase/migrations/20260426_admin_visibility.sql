-- Migration: admin visibility for users and MT5 accounts
-- Purpose: allow backend/admin reads on profiles and trading_accounts,
-- and keep the user-to-MT5 link visible in the admin API.

BEGIN;

-- Helper used by RLS policies without recursive self-checks.
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles admin_profile
        WHERE admin_profile.id = auth.uid()
          AND admin_profile.role = 'ADMIN'
    );
$$;

-- Profiles: own read + admin read.
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
USING (public.is_admin_user());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

-- Trading accounts: own read + admin read.
DROP POLICY IF EXISTS "Users can view own accounts" ON public.trading_accounts;
CREATE POLICY "Users can view own accounts"
ON public.trading_accounts
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all trading accounts" ON public.trading_accounts;
CREATE POLICY "Admins can view all trading accounts"
ON public.trading_accounts
FOR SELECT
USING (public.is_admin_user());

COMMIT;
