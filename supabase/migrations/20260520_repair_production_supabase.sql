BEGIN;

-- Ensure required UUID helpers are available.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------
-- Storage: kyc-documents bucket + RLS policies
-- ------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', false)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public;

-- Storage policies must be applied by the storage table owner (Supabase
-- typically executes these with elevated privileges in the dashboard, but if
-- your current SQL role is not the owner, run the owner-only script below.

-- ------------------------------------------------------------
-- Branding runtime settings: public.app_settings
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    app_name TEXT NOT NULL DEFAULT 'FrappedDollars',
    tagline TEXT NOT NULL DEFAULT 'Copy trading automatique pour comptes MT5.',
    logo_url TEXT,
    primary_color_hex TEXT NOT NULL DEFAULT '#00C853',
    background_color_hex TEXT NOT NULL DEFAULT '#121212',
    support_email TEXT,
    support_phone TEXT,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_settings (
    id,
    app_name,
    tagline,
    logo_url,
    primary_color_hex,
    background_color_hex,
    support_email,
    support_phone,
    updated_at
)
VALUES (
    1,
    'FrappedDollars',
    'Copy trading automatique pour comptes MT5.',
    NULL,
    '#00C853',
    '#121212',
    NULL,
    NULL,
    NOW()
)
ON CONFLICT (id) DO UPDATE
SET app_name = EXCLUDED.app_name,
    tagline = EXCLUDED.tagline,
    logo_url = EXCLUDED.logo_url,
    primary_color_hex = EXCLUDED.primary_color_hex,
    background_color_hex = EXCLUDED.background_color_hex,
    support_email = EXCLUDED.support_email,
    support_phone = EXCLUDED.support_phone,
    updated_at = NOW();

-- ------------------------------------------------------------
-- DOB sync: ensure new users + backfill existing profiles
-- ------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS phone_number TEXT,
    ADD COLUMN IF NOT EXISTS date_of_birth DATE,
    ADD COLUMN IF NOT EXISTS kyc_status TEXT NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS kyc_blocked BOOLEAN NOT NULL DEFAULT TRUE;

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
        phone_number,
        date_of_birth,
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
        NULLIF(NEW.raw_user_meta_data ->> 'phone_number', ''),
        NULLIF(NEW.raw_user_meta_data ->> 'date_of_birth', '')::date,
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
        phone_number = COALESCE(EXCLUDED.phone_number, public.profiles.phone_number),
        date_of_birth = COALESCE(EXCLUDED.date_of_birth, public.profiles.date_of_birth),
        updated_at = NOW();

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

DO $$
BEGIN
    IF to_regclass('public.profiles') IS NOT NULL AND to_regclass('auth.users') IS NOT NULL THEN
        UPDATE public.profiles p
        SET
            phone_number = COALESCE(p.phone_number, NULLIF(u.raw_user_meta_data ->> 'phone_number', '')),
            date_of_birth = COALESCE(p.date_of_birth, NULLIF(u.raw_user_meta_data ->> 'date_of_birth', '')::date),
            full_name = COALESCE(
                p.full_name,
                NULLIF(u.raw_user_meta_data ->> 'full_name', ''),
                NULLIF(u.raw_user_meta_data ->> 'name', ''),
                NULLIF(u.raw_user_meta_data ->> 'display_name', ''),
                SPLIT_PART(COALESCE(u.email, ''), '@', 1)
            ),
            updated_at = NOW()
        FROM auth.users u
        WHERE u.id = p.id;
    END IF;
END
$$;

COMMIT;
