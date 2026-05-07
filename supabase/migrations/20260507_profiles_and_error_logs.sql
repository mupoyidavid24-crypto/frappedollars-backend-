-- Migration: profile sync + centralized error logging
-- Purpose:
-- - Ensure every Supabase Auth user gets a row in public.profiles
-- - Backfill existing auth users into public.profiles
-- - Create centralized public.errors_logs for backend + MT5 error visibility

BEGIN;

-- Keep profile rows in sync with Supabase Auth users.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        role,
        is_vip,
        needs_vps,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(
            NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''),
            NULLIF(NEW.raw_user_meta_data ->> 'name', ''),
            NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''),
            SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
        ),
        'CLIENT',
        FALSE,
        FALSE,
        COALESCE(NEW.created_at, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
        updated_at = NOW();

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Backfill existing auth users that do not yet have a profile row.
INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    is_vip,
    needs_vps,
    created_at,
    updated_at
)
SELECT
    u.id,
    COALESCE(u.email, ''),
    COALESCE(
        NULLIF(u.raw_user_meta_data ->> 'full_name', ''),
        NULLIF(u.raw_user_meta_data ->> 'name', ''),
        NULLIF(u.raw_user_meta_data ->> 'display_name', ''),
        SPLIT_PART(COALESCE(u.email, ''), '@', 1)
    ),
    'CLIENT',
    FALSE,
    FALSE,
    COALESCE(u.created_at, NOW()),
    NOW()
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;

-- Centralized error logs for backend and MT5.
CREATE TABLE IF NOT EXISTS public.errors_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    source TEXT NOT NULL,
    component TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'ERROR',
    message TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    mt5_login TEXT,
    trade_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_errors_logs_created_at ON public.errors_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_errors_logs_severity ON public.errors_logs(severity);
CREATE INDEX IF NOT EXISTS idx_errors_logs_source ON public.errors_logs(source);

ALTER TABLE public.errors_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all error logs" ON public.errors_logs;
CREATE POLICY "Admins can view all error logs"
ON public.errors_logs
FOR SELECT
USING (public.is_admin_user());

COMMIT;
