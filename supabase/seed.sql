-- DEVELOPMENT fixtures only. Never use db push --include-seed on production.
-- pnpm db:test embeds this file twice INSIDE a rollback-only remote test transaction.
-- Optional local resets may load it persistently; remote tests leave no fixtures behind.
-- No Auth users, profiles, passwords, invitation codes or personal data.
-- Stable IDs make repeated seeding safe without depending on team names being unique.
insert into public.competitions (id, nombre) values
  ('10000000-0000-4000-8000-000000000001', 'Demo Liga'),
  ('10000000-0000-4000-8000-000000000002', 'Demo Copa')
on conflict do nothing;

insert into public.teams (id, nombre) values
  ('20000000-0000-4000-8000-000000000001', 'Demo Norte'),
  ('20000000-0000-4000-8000-000000000002', 'Demo Sur'),
  ('20000000-0000-4000-8000-000000000003', 'Demo Este'),
  ('20000000-0000-4000-8000-000000000004', 'Demo Oeste'),
  ('20000000-0000-4000-8000-000000000005', 'Demo Centro'),
  ('20000000-0000-4000-8000-000000000006', 'Demo Costa'),
  ('20000000-0000-4000-8000-000000000007', 'Demo Sierra'),
  ('20000000-0000-4000-8000-000000000008', 'Demo Valle'),
  ('20000000-0000-4000-8000-000000000009', 'Demo Isla'),
  ('20000000-0000-4000-8000-000000000010', 'Demo Puerto')
on conflict (id) do nothing;
