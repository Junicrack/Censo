// Edge Function "usuarios": crear y administrar los usuarios del censo.
// Solo un admin puede usarla, salvo "inicial", que crea el primer admin
// y queda bloqueada en cuanto existe uno.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const DOMINIO = "censo.app"; // los usuarios entran con "usuario"; por dentro es usuario@censo.app
const ROLES = ["censador", "manager", "admin"];

function resp(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
function limpiarUsuario(u: unknown) {
  const s = String(u ?? "").trim().toLowerCase();
  return /^[a-z0-9._-]{3,30}$/.test(s) ? s : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resp({ error: "Método no permitido" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return resp({ error: "Datos no válidos" }, 400); }
  const accion = String(body.accion ?? "");

  async function crear(usuario: string, clave: string, nombre: string, rol: string) {
    if (String(clave).length < 6) return resp({ error: "La clave debe tener al menos 6 caracteres" }, 400);
    if (!nombre.trim()) return resp({ error: "Falta el nombre" }, 400);
    if (!ROLES.includes(rol)) return resp({ error: "Rol no válido" }, 400);
    const { data, error } = await admin.auth.admin.createUser({
      email: `${usuario}@${DOMINIO}`, password: clave, email_confirm: true,
      user_metadata: { usuario, nombre },
    });
    if (error) {
      const msg = /already|registered|exists/i.test(error.message) ? "Ese usuario ya existe" : error.message;
      return resp({ error: msg }, 400);
    }
    const { error: e2 } = await admin.from("perfiles").insert({ id: data.user.id, usuario, nombre: nombre.trim(), rol });
    if (e2) { await admin.auth.admin.deleteUser(data.user.id); return resp({ error: e2.message }, 400); }
    return resp({ ok: true, id: data.user.id });
  }

  // 1) Primer administrador (solo si todavía no hay ninguno)
  if (accion === "inicial") {
    const { count } = await admin.from("perfiles").select("id", { count: "exact", head: true }).eq("rol", "admin");
    if ((count ?? 0) > 0) return resp({ error: "Ya existe un administrador" }, 403);
    const u = limpiarUsuario(body.usuario);
    if (!u) return resp({ error: "Usuario no válido (3 a 30 letras, números, punto o guion)" }, 400);
    return await crear(u, String(body.clave ?? ""), String(body.nombre ?? ""), "admin");
  }
  if (accion === "hay_admin") {
    const { count } = await admin.from("perfiles").select("id", { count: "exact", head: true }).eq("rol", "admin");
    return resp({ hay_admin: (count ?? 0) > 0 });
  }

  // 2) El resto exige ser admin activo
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: quien, error: eq } = await admin.auth.getUser(token);
  if (eq || !quien?.user) return resp({ error: "Sesión no válida" }, 401);
  const { data: perfil } = await admin.from("perfiles").select("rol, activo").eq("id", quien.user.id).single();
  if (!perfil || perfil.rol !== "admin" || !perfil.activo) return resp({ error: "Solo el administrador puede hacer esto" }, 403);

  if (accion === "crear") {
    const u = limpiarUsuario(body.usuario);
    if (!u) return resp({ error: "Usuario no válido (3 a 30 letras, números, punto o guion)" }, 400);
    return await crear(u, String(body.clave ?? ""), String(body.nombre ?? ""), String(body.rol ?? ""));
  }

  const id = String(body.id ?? "");
  if (!id) return resp({ error: "Falta el usuario" }, 400);

  if (accion === "clave") {
    if (String(body.clave ?? "").length < 6) return resp({ error: "La clave debe tener al menos 6 caracteres" }, 400);
    const { error } = await admin.auth.admin.updateUserById(id, { password: String(body.clave) });
    return error ? resp({ error: error.message }, 400) : resp({ ok: true });
  }

  if (accion === "estado") {
    if (id === quien.user.id) return resp({ error: "No puedes desactivarte a ti mismo" }, 400);
    const activo = !!body.activo;
    const { error } = await admin.from("perfiles").update({ activo }).eq("id", id);
    if (error) return resp({ error: error.message }, 400);
    // Desactivado = se le cierra la sesión y no puede volver a entrar
    await admin.auth.admin.updateUserById(id, { ban_duration: activo ? "none" : "876000h" });
    return resp({ ok: true });
  }

  if (accion === "rol") {
    const rol = String(body.rol ?? "");
    if (!ROLES.includes(rol)) return resp({ error: "Rol no válido" }, 400);
    if (id === quien.user.id && rol !== "admin") return resp({ error: "No puedes quitarte el rol de admin" }, 400);
    const { error } = await admin.from("perfiles").update({ rol }).eq("id", id);
    return error ? resp({ error: error.message }, 400) : resp({ ok: true });
  }

  return resp({ error: "Acción desconocida" }, 400);
});
