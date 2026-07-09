-- ICONIC BARBEARIA — Fase 2: autoatendimento multi-tenant (rodar no SQL Editor)
-- Pré-requisito: já ter rodado supabase/schema.sql

-- ── LOGO PERSONALIZADO POR BARBEARIA ────────────────────────────────────────
alter table organizations add column if not exists logo_url text;

-- ── PROVISIONAMENTO AUTOMÁTICO (chamado pelo app logo após o cadastro) ─────
create or replace function create_my_organization(org_name text, dono_nome text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
  new_slug text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'user already has an organization';
  end if;

  new_slug := lower(regexp_replace(trim(org_name), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text),1,6);

  insert into organizations (nome, slug) values (org_name, new_slug) returning id into new_org_id;
  insert into profiles (id, org_id, nome, role) values (auth.uid(), new_org_id, dono_nome, 'dono');

  insert into org_data (org_id, data) values (new_org_id, jsonb_build_object(
    'barbs', '[]'::jsonb,
    'meta', 10000,
    'txB', 50, 'txBar', 50,
    'cnpj', '',
    'svcs', '[]'::jsonb, 'avul', '[]'::jsonb, 'ext', '[]'::jsonb, 'extAv', '[]'::jsonb,
    'prod', '[]'::jsonb, 'pote', '[]'::jsonb, 'lote', '[]'::jsonb,
    'assinD', jsonb_build_object('ativas',0,'novas',0,'canceladas',0),
    'assinV', '[]'::jsonb, 'vales', '[]'::jsonb,
    'prodLst', '[]'::jsonb, 'estoque', '{}'::jsonb,
    'niveis', jsonb_build_array(
      jsonb_build_object('nome','Bronze','valor',3000,'cor','#b45309','icon','🥉'),
      jsonb_build_object('nome','Prata','valor',6000,'cor','#6b7280','icon','🥈'),
      jsonb_build_object('nome','Ouro','valor',10000,'cor','#d97706','icon','🥇'),
      jsonb_build_object('nome','Diamante','valor',15000,'cor','#0891b2','icon','💎')
    ),
    'metasBon', '[]'::jsonb,
    'coaching', '[]'::jsonb, 'metaHist', '[]'::jsonb, 'horasTrab', '{}'::jsonb, 'auditLog', '[]'::jsonb,
    'instaMeta', jsonb_build_object('storiesQt',20,'storiesBon',50,'reelsQt',10,'reelsBon',50),
    'instaLancamentos', '[]'::jsonb, 'desafioPessoal', '{}'::jsonb,
    'desafio', jsonb_build_object('servico','sobrancelhas','qt',10,'pontos',50)
  ));

  return new_org_id;
end;
$$;

grant execute on function create_my_organization(text, text) to authenticated;

-- ── STORAGE: bucket de logos (leitura pública, escrita só do próprio dono) ─
insert into storage.buckets (id, name, public)
values ('logos', 'logos', true)
on conflict (id) do nothing;

create policy "logos_public_read" on storage.objects for select using (bucket_id = 'logos');

create policy "logos_owner_insert" on storage.objects for insert with check (
  bucket_id = 'logos' and (storage.foldername(name))[1] = auth_org_id()::text and auth_role() = 'dono'
);

create policy "logos_owner_update" on storage.objects for update using (
  bucket_id = 'logos' and (storage.foldername(name))[1] = auth_org_id()::text and auth_role() = 'dono'
) with check (
  bucket_id = 'logos' and (storage.foldername(name))[1] = auth_org_id()::text and auth_role() = 'dono'
);

create policy "logos_owner_delete" on storage.objects for delete using (
  bucket_id = 'logos' and (storage.foldername(name))[1] = auth_org_id()::text and auth_role() = 'dono'
);
