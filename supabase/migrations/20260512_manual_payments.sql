BEGIN;

ALTER TABLE public.payments
    ADD COLUMN IF NOT EXISTS payment_type TEXT NOT NULL DEFAULT 'COPY_TRADING_WEEKLY',
    ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'PENDING_VALIDATION',
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS recipient_number TEXT,
    ADD COLUMN IF NOT EXISTS proof_url TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS reviewer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS review_reason TEXT;

UPDATE public.payments
SET payment_status = CASE
    WHEN UPPER(COALESCE(statut, '')) IN ('VALIDÉ', 'VALIDE', 'VALIDATED', 'APPROVED') THEN 'APPROVED'
    WHEN UPPER(COALESCE(statut, '')) IN ('REFUSÉ', 'REFUSE', 'REFUSED', 'REJECTED') THEN 'REJECTED'
    ELSE 'PENDING_VALIDATION'
END,
payment_type = COALESCE(payment_type, 'COPY_TRADING_WEEKLY'),
amount = COALESCE(amount, montant),
proof_url = COALESCE(proof_url, preuve),
review_reason = COALESCE(review_reason, motif)
WHERE payment_status IS NULL OR proof_url IS NULL OR review_reason IS NULL;

ALTER TABLE public.payments
    ALTER COLUMN payment_status SET DEFAULT 'PENDING_VALIDATION';

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
CREATE POLICY "Users can view own payments"
ON public.payments
FOR SELECT
USING (auth.uid() = client);

DROP POLICY IF EXISTS "Users can insert own payments" ON public.payments;
CREATE POLICY "Users can insert own payments"
ON public.payments
FOR INSERT
WITH CHECK (auth.uid() = client);

DROP POLICY IF EXISTS "Admins can manage all payments" ON public.payments;
CREATE POLICY "Admins can manage all payments"
ON public.payments
FOR ALL
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

CREATE INDEX IF NOT EXISTS idx_payments_payment_status ON public.payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_payment_type ON public.payments(payment_type);

COMMIT;