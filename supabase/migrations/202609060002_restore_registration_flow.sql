-- Restore the registration behaviour from before 5 September, 9:30 PM.
-- Safe whether or not the duplicate-image migration was previously applied.
-- Only disconnect the later image-uniqueness checks; no user/document data,
-- existing email/identity constraints, approval rules or RLS policies are removed.
begin;
drop trigger if exists module400_citizen_document_uniqueness on public.citizens;
drop trigger if exists module400_tourist_document_uniqueness on public.tourists;
notify pgrst, 'reload schema';
commit;
