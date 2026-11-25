-- Migración 3: eliminar usuarios sin borrar sus registros, y conteo de registros por censador.
-- Al eliminar un usuario se borra su cuenta de acceso (auth.users), pero su perfil se queda
-- marcado como eliminado para que sus viviendas sigan mostrando quién las registró.

alter table public.perfiles add column if not exists eliminado timestamptz;

-- El perfil ya no depende de la cuenta de acceso (antes se borraba en cascada)
alter table public.perfiles drop constraint if exists perfiles_id_fkey;

-- El nombre de usuario de alguien eliminado se puede volver a usar
alter table public.perfiles drop constraint if exists perfiles_usuario_key;
create unique index if not exists perfiles_usuario_vivo on public.perfiles (usuario) where eliminado is null;

-- Un usuario eliminado no tiene rol (no puede ver ni hacer nada)
create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from public.perfiles where id = auth.uid() and activo and eliminado is null
$$;

-- Cuántos registros y personas ha subido cada censador (respeta RLS: el censador solo ve los suyos)
create or replace function public.conteo_por_censador()
returns table (censador_id uuid, registros bigint, personas bigint)
language sql stable security invoker set search_path = public as $$
  select v.censador_id, count(*),
         coalesce(sum(case when jsonb_typeof(v.datos->'miembros') = 'array'
                           then jsonb_array_length(v.datos->'miembros') else 0 end), 0)
  from public.viviendas v
  group by v.censador_id
$$;
revoke execute on function public.conteo_por_censador() from anon, public;
grant execute on function public.conteo_por_censador() to authenticated;
