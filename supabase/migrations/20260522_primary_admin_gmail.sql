BEGIN;

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
    COALESCE(u.email, 'frappedollarsofficiel@gmail.com'),
    COALESCE(
        NULLIF(u.raw_user_meta_data ->> 'full_name', ''),
        NULLIF(u.raw_user_meta_data ->> 'name', ''),
        NULLIF(u.raw_user_meta_data ->> 'display_name', ''),
        SPLIT_PART(COALESCE(u.email, 'frappedollarsofficiel@gmail.com'), '@', 1)
    ),
    'ADMIN',
    FALSE,
    FALSE,
    COALESCE(u.created_at, NOW()),
    NOW()
FROM auth.users u
WHERE LOWER(COALESCE(u.email, '')) = LOWER('frappedollarsofficiel@gmail.com')
ON CONFLICT (id) DO UPDATE
SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
    role = 'ADMIN',
    updated_at = NOW();

UPDATE public.profiles
SET role = 'ADMIN',
    updated_at = NOW()
WHERE LOWER(email) = LOWER('frappedollarsofficiel@gmail.com');

COMMIT;