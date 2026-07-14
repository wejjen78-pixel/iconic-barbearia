-- ICONIC APP — Integração GalaxPay (Cel Cash) — rodar no SQL Editor
-- Pré-requisito: já ter rodado schema.sql e schema_v2_saas.sql

-- ── CREDENCIAIS DE INTEGRAÇÃO (nunca legível pelo navegador) ───────────────
create table org_integrations (
  org_id uuid primary key references organizations(id) on delete cascade,
  provider text not null default 'galaxpay',
  galax_id text,
  galax_hash text,
  last_sync_at timestamptz,
  last_sync_count int,
  criado_em timestamptz not null default now()
);

alter table org_integrations enable row level security;

-- Ninguém consegue SELECT (nem o dono) — só a Edge Function via service role,
-- que ignora RLS. Isso evita que o galaxHash apareça em qualquer resposta ao navegador.
-- O dono só consegue INSERT/UPDATE (escrever, nunca ler de volta).
create policy "org_integrations_write" on org_integrations for insert with check (
  org_id = auth_org_id() and auth_role() = 'dono'
);
create policy "org_integrations_update" on org_integrations for update using (
  org_id = auth_org_id() and auth_role() = 'dono'
) with check (
  org_id = auth_org_id() and auth_role() = 'dono'
);

-- Função auxiliar: dono consegue checar status da integração sem nunca ver o hash salvo.
create or replace function get_galaxpay_status()
returns table(configured boolean, last_sync_at timestamptz, last_sync_count int)
language sql stable security definer
set search_path = public
as $$
  select
    (galax_id is not null and galax_hash is not null) as configured,
    last_sync_at,
    last_sync_count
  from org_integrations where org_id = auth_org_id()
  union all
  select false, null, null where not exists(select 1 from org_integrations where org_id = auth_org_id())
  limit 1
$$;

grant execute on function get_galaxpay_status() to authenticated;
