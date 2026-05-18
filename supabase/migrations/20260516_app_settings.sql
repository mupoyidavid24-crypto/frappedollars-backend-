BEGIN;

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
ON CONFLICT (id) DO NOTHING;

COMMIT;
