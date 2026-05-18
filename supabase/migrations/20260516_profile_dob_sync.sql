BEGIN;

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

COMMIT;
