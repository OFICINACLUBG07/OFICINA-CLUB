-- Oficina Club - estrutura inicial do banco online
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  email text unique,
  perfil text not null default 'admin' check (perfil in ('admin','atendente','mecanico','caixa')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists public.empresas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  descricao text,
  cnpj text,
  telefone text,
  email text,
  endereco text,
  cidade text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  documento text,
  telefone text,
  email text,
  endereco text,
  observacoes text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.veiculos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references public.clientes(id) on delete set null,
  placa text,
  marca text,
  modelo text,
  ano text,
  cor text,
  combustivel text,
  km integer,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.produtos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('Peça','Serviço')),
  codigo text,
  descricao text not null,
  preco numeric(12,2) not null default 0,
  estoque numeric(12,2) not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.ordens_servico (
  id uuid primary key default gen_random_uuid(),
  numero text not null unique,
  cliente_id uuid references public.clientes(id) on delete set null,
  veiculo_id uuid references public.veiculos(id) on delete set null,
  cliente_nome text,
  cliente_telefone text,
  cliente_documento text,
  placa_avulsa text,
  marca_avulsa text,
  modelo_avulso text,
  ano_avulso text,
  km_avulsa integer,
  status text not null default 'Aberta' check (status in ('Aberta','Em diagnóstico','Aguardando aprovação','Aprovada','Em execução','Finalizada','Entregue','Cancelada')),
  previsao date,
  reclamacao text not null,
  diagnostico text,
  total numeric(12,2) not null default 0,
  criado_por uuid references public.profiles(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.itens_ordem_servico (
  id uuid primary key default gen_random_uuid(),
  ordem_id uuid not null references public.ordens_servico(id) on delete cascade,
  produto_id uuid references public.produtos(id) on delete set null,
  tipo text not null check (tipo in ('Peça','Serviço')),
  descricao text not null,
  quantidade numeric(12,2) not null default 1,
  preco numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  criado_em timestamptz not null default now()
);

create table if not exists public.movimentos_estoque (
  id uuid primary key default gen_random_uuid(),
  produto_id uuid not null references public.produtos(id) on delete cascade,
  tipo text not null check (tipo in ('entrada','saida','ajuste')),
  quantidade numeric(12,2) not null,
  observacao text,
  ordem_id uuid references public.ordens_servico(id) on delete set null,
  criado_por uuid references public.profiles(id) on delete set null,
  criado_em timestamptz not null default now()
);

create table if not exists public.pagamentos (
  id uuid primary key default gen_random_uuid(),
  ordem_id uuid not null references public.ordens_servico(id) on delete cascade,
  forma text,
  valor numeric(12,2) not null default 0,
  observacao text,
  criado_em timestamptz not null default now()
);

create table if not exists public.historico_ordens (
  id uuid primary key default gen_random_uuid(),
  ordem_id uuid not null references public.ordens_servico(id) on delete cascade,
  descricao text not null,
  criado_por uuid references public.profiles(id) on delete set null,
  criado_em timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

drop trigger if exists trg_empresas_updated_at on public.empresas;
create trigger trg_empresas_updated_at before update on public.empresas for each row execute function public.set_updated_at();
drop trigger if exists trg_clientes_updated_at on public.clientes;
create trigger trg_clientes_updated_at before update on public.clientes for each row execute function public.set_updated_at();
drop trigger if exists trg_veiculos_updated_at on public.veiculos;
create trigger trg_veiculos_updated_at before update on public.veiculos for each row execute function public.set_updated_at();
drop trigger if exists trg_produtos_updated_at on public.produtos;
create trigger trg_produtos_updated_at before update on public.produtos for each row execute function public.set_updated_at();
drop trigger if exists trg_ordens_updated_at on public.ordens_servico;
create trigger trg_ordens_updated_at before update on public.ordens_servico for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nome', new.email), new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.empresas enable row level security;
alter table public.clientes enable row level security;
alter table public.veiculos enable row level security;
alter table public.produtos enable row level security;
alter table public.ordens_servico enable row level security;
alter table public.itens_ordem_servico enable row level security;
alter table public.movimentos_estoque enable row level security;
alter table public.pagamentos enable row level security;
alter table public.historico_ordens enable row level security;

create policy if not exists "authenticated read profiles" on public.profiles for select to authenticated using (true);
create policy if not exists "authenticated update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy if not exists "authenticated full empresas" on public.empresas for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full clientes" on public.clientes for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full veiculos" on public.veiculos for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full produtos" on public.produtos for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full ordens" on public.ordens_servico for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full itens ordens" on public.itens_ordem_servico for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full estoque" on public.movimentos_estoque for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full pagamentos" on public.pagamentos for all to authenticated using (true) with check (true);
create policy if not exists "authenticated full historico" on public.historico_ordens for all to authenticated using (true) with check (true);

insert into public.empresas (nome, descricao, cnpj, telefone, email, endereco, cidade)
select 'Oficina Club', 'Peças, Serviços e Acessórios', '17.294.997/0001-32', '(16) 99374-1409', 'oficinaclub@outlook.com', 'Área Rural, Rodovia Cravinhos a Bonfim', 'Cravinhos/SP'
where not exists (select 1 from public.empresas);
