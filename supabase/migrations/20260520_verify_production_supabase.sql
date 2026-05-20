SELECT 'bucket_kyc_documents' AS check_name, COUNT(*)::int AS count
FROM storage.buckets
WHERE id = 'kyc-documents'

UNION ALL

SELECT 'policy_storage_objects' AS check_name, COUNT(*)::int AS count
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname IN (
      'KYC docs owner can read',
      'KYC docs owner can upload',
      'KYC docs owner can delete',
      'KYC docs admin can manage'
  )

UNION ALL

SELECT 'table_app_settings' AS check_name, COUNT(*)::int AS count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'app_settings'

UNION ALL

SELECT 'app_settings_row' AS check_name, COUNT(*)::int AS count
FROM public.app_settings
WHERE id = 1

UNION ALL

SELECT 'table_kyc_documents' AS check_name, COUNT(*)::int AS count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'kyc_documents'

UNION ALL

SELECT 'table_payments' AS check_name, COUNT(*)::int AS count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'payments'

UNION ALL

SELECT 'table_business_rules' AS check_name, COUNT(*)::int AS count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'business_rules'

UNION ALL

SELECT 'profiles_date_of_birth_column' AS check_name, COUNT(*)::int AS count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
  AND column_name = 'date_of_birth'

UNION ALL

SELECT 'profiles_phone_number_column' AS check_name, COUNT(*)::int AS count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
  AND column_name = 'phone_number'

UNION ALL

SELECT 'auth_user_trigger' AS check_name, COUNT(*)::int AS count
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users'
  AND trigger_name = 'on_auth_user_created'
;