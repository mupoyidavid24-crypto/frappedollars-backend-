    BEGIN;

DO $$
BEGIN
    IF to_regclass('public.kyc_documents') IS NULL THEN
        CREATE TABLE public.kyc_documents (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
            document_type TEXT NOT NULL CHECK (document_type IN ('NATIONAL_ID', 'VOTER_ID', 'PASSPORT')),
            document_number TEXT,
            address_line TEXT NOT NULL,
            country TEXT NOT NULL,
            city TEXT NOT NULL,
            file_url TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
            reviewer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
            reviewer_note TEXT,
            submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            reviewed_at TIMESTAMPTZ
        );

        CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id ON public.kyc_documents(user_id);
        CREATE INDEX IF NOT EXISTS idx_kyc_documents_status ON public.kyc_documents(status);


        ALTER TABLE public.kyc_documents ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Users can view own KYC documents" ON public.kyc_documents;
        CREATE POLICY "Users can view own KYC documents"
        ON public.kyc_documents
        FOR SELECT
        USING (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can insert own KYC documents" ON public.kyc_documents;
        CREATE POLICY "Users can insert own KYC documents"
        ON public.kyc_documents
        FOR INSERT
        WITH CHECK (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Admins can manage all KYC documents" ON public.kyc_documents;
        CREATE POLICY "Admins can manage all KYC documents"
        ON public.kyc_documents
        FOR ALL
        USING (public.is_admin_user());
    END IF;
END;
$$;

ALTER TABLE public.kyc_documents
    ADD COLUMN IF NOT EXISTS reason TEXT;

UPDATE public.kyc_documents
SET reason = COALESCE(reason, reviewer_note)
WHERE reason IS NULL AND reviewer_note IS NOT NULL;

ALTER TABLE public.kyc_documents
    ALTER COLUMN reason SET DEFAULT '';

COMMIT;
