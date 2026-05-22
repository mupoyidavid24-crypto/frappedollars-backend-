BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'NORMAL',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

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

DO $$
BEGIN
    IF to_regclass('public.notifications') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage notifications" ON public.notifications';
        EXECUTE 'CREATE POLICY "Admins can manage notifications" ON public.notifications FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;

    IF to_regclass('public.errors_logs') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.errors_logs ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can manage error logs" ON public.errors_logs';
        EXECUTE 'CREATE POLICY "Admins can manage error logs" ON public.errors_logs FOR ALL USING (public.is_admin_user()) WITH CHECK (public.is_admin_user())';
    END IF;

    IF to_regclass('public.copied_trades') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.copied_trades ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "Admins can view copied trades" ON public.copied_trades';
        EXECUTE 'CREATE POLICY "Admins can view copied trades" ON public.copied_trades FOR SELECT USING (public.is_admin_user())';
    END IF;
END
$$;

COMMIT;