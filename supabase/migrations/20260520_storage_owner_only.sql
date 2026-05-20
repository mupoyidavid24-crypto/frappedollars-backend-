BEGIN;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "KYC docs owner can read" ON storage.objects;
CREATE POLICY "KYC docs owner can read"
ON storage.objects
FOR SELECT
USING (
    bucket_id = 'kyc-documents'
    AND auth.uid()::text = split_part(name, '/', 1)
);

DROP POLICY IF EXISTS "KYC docs owner can upload" ON storage.objects;
CREATE POLICY "KYC docs owner can upload"
ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'kyc-documents'
    AND auth.uid()::text = split_part(name, '/', 1)
);

DROP POLICY IF EXISTS "KYC docs owner can delete" ON storage.objects;
CREATE POLICY "KYC docs owner can delete"
ON storage.objects
FOR DELETE
USING (
    bucket_id = 'kyc-documents'
    AND auth.uid()::text = split_part(name, '/', 1)
);

DROP POLICY IF EXISTS "KYC docs admin can manage" ON storage.objects;
CREATE POLICY "KYC docs admin can manage"
ON storage.objects
FOR ALL
USING (
    bucket_id = 'kyc-documents'
    AND public.is_admin_user()
)
WITH CHECK (
    bucket_id = 'kyc-documents'
    AND public.is_admin_user()
);

COMMIT;