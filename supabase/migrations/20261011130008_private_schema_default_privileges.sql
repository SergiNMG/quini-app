-- Keep future helper functions in the unexposed schema private by default.
-- Existing is_active_member/is_active_admin grants are unchanged; policies still use them.
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated, service_role;
