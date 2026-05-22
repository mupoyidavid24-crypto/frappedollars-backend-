BEGIN;

DO $$
BEGIN
    IF to_regclass('public.business_rules') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.business_rules ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage business rules" ON public.business_rules';
        EXECUTE 'CREATE POLICY "Admins can manage business rules" ON public.business_rules FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;

    IF to_regclass('public.payment_methods') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage payment methods" ON public.payment_methods';
        EXECUTE 'CREATE POLICY "Admins can manage payment methods" ON public.payment_methods FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;

    IF to_regclass('public.vps_assignments') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.vps_assignments ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage VPS assignments" ON public.vps_assignments';
        EXECUTE 'CREATE POLICY "Admins can manage VPS assignments" ON public.vps_assignments FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;

    IF to_regclass('public.notifications') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage notifications" ON public.notifications';
        EXECUTE 'CREATE POLICY "Admins can manage notifications" ON public.notifications FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;
END
$$;

COMMIT;