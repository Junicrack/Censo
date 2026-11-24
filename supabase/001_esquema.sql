-- Censo Comunitario: esquema en la nube (Supabase / Postgres)
-- Roles: censador, manager, admin. Los permisos los impone la base de datos (RLS).

-- Perfil de cada usuario (uno por cuenta de Supabase Auth)
create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  usuario text not null unique,
  nombre text not null,
  rol text not null check (rol in ('censador','manager','admin')),
  activo boolean not null default true,
  creado timestamptz not null default now()
);

-- Configuración general (una sola fila): abrir / cerrar el ingreso de datos
create table public.config (
  id int primary key default 1 check (id = 1),
  censo_abierto boolean not null default true,
  cerrado_en timestamptz,
  cerrado_por uuid references public.perfiles(id)
);
insert into public.config (id) values (1);

-- Un registro = una vivienda con sus personas (miembros en JSON, igual que la app)
create table public.viviendas (
  id text primary key,                       -- id generado en el teléfono (permite trabajar sin señal)
  datos jsonb not null,                      -- registro completo tal como lo guarda la app
  sector text generated always as (datos->>'sector') stored,
  censador_id uuid not null references public.perfiles(id) default auth.uid(),
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
create index on public.viviendas (sector);
create index on public.viviendas (censador_id);

-- Funciones de ayuda (security definer para no recursar en RLS)
create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from public.perfiles where id = auth.uid() and activo
$$;

create or replace function public.censo_abierto() returns boolean
language sql stable security definer set search_path = public as $$
  select censo_abierto from public.config where id = 1
$$;

alter table public.perfiles  enable row level security;
alter table public.config    enable row level security;
alter table public.viviendas enable row level security;

-- PERFILES: cada quien ve el suyo; manager y admin ven todos; solo admin modifica
create policy perfiles_ver on public.perfiles for select to authenticated
  using (id = auth.uid() or public.mi_rol() in ('manager','admin'));
create policy perfiles_admin on public.perfiles for all to authenticated
  using (public.mi_rol() = 'admin') with check (public.mi_rol() = 'admin');

-- CONFIG: todos los usuarios activos la leen; solo admin la cambia
create policy config_ver on public.config for select to authenticated
  using (public.mi_rol() is not null);
create policy config_admin on public.config for update to authenticated
  using (public.mi_rol() = 'admin') with check (public.mi_rol() = 'admin');

-- VIVIENDAS
-- Ver: censador solo las suyas; manager y admin todas
create policy viv_ver on public.viviendas for select to authenticated
  using (censador_id = auth.uid() and public.mi_rol() = 'censador'
         or public.mi_rol() in ('manager','admin'));
-- Crear: censador y admin, solo con el censo abierto
create policy viv_crear on public.viviendas for insert to authenticated
  with check (public.censo_abierto()
              and public.mi_rol() in ('censador','admin')
              and censador_id = auth.uid());
-- Editar: censador las suyas, admin cualquiera; solo con el censo abierto
create policy viv_editar on public.viviendas for update to authenticated
  using (public.censo_abierto()
         and (censador_id = auth.uid() and public.mi_rol() = 'censador' or public.mi_rol() = 'admin'))
  with check (public.censo_abierto());
-- Borrar: solo admin
create policy viv_borrar on public.viviendas for delete to authenticated
  using (public.mi_rol() = 'admin');

-- El servidor pone la fecha de actualización y no deja cambiar quién lo registró
create or replace function public.viv_antes_de_guardar() returns trigger
language plpgsql set search_path = public as $$
begin
  new.actualizado := now();
  if tg_op = 'UPDATE' then
    new.censador_id := old.censador_id;
    new.creado := old.creado;
  end if;
  return new;
end $$;
create trigger viv_antes_de_guardar before insert or update on public.viviendas
  for each row execute function public.viv_antes_de_guardar();

-- Registro de cierres/aperturas
create or replace function public.config_antes_de_guardar() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.censo_abierto is distinct from old.censo_abierto then
    new.cerrado_en := case when new.censo_abierto then null else now() end;
    new.cerrado_por := case when new.censo_abierto then null else auth.uid() end;
  end if;
  return new;
end $$;
create trigger config_antes_de_guardar before update on public.config
  for each row execute function public.config_antes_de_guardar();

-- Los visitantes sin sesión no tienen acceso a nada
revoke all on public.perfiles, public.config, public.viviendas from anon;
revoke execute on function public.mi_rol(), public.censo_abierto() from anon, public;
grant execute on function public.mi_rol(), public.censo_abierto() to authenticated;
