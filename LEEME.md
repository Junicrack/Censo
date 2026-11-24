# Censo Comunitario

Una sola app que sirve como página web (HTML) y como aplicación Android (APK).
Funciona sin internet. Los registros se guardan en el propio equipo.

## Carpetas

- `www/` – la app web. `index.html` es todo el programa.
- `android/` – proyecto Android que empaqueta `www/` dentro de un APK.
- `.github/workflows/apk.yml` – construye el APK automáticamente en GitHub.

## Usarla como HTML

- **En una computadora:** abrir `www/index.html` con Chrome o Edge.
- **En el celular sin instalar nada:** subir la carpeta `www/` a un hosting
  gratuito (GitHub Pages, Netlify) y abrir el enlace en Chrome. Menú ⋮ →
  "Agregar a pantalla principal". Queda como app y funciona sin internet.

## APK automático

Cada vez que cambia algo en `www/` o `android/` dentro de la rama `main` de GitHub,
el flujo `.github/workflows/apk.yml`:

1. Construye el APK firmado siempre con la misma llave (así se instala encima
   del anterior y los registros se conservan).
2. Le pone un número de versión nuevo (1.N).
3. Lo publica en *Releases*. El enlace fijo a la última versión es
   `https://github.com/USUARIO/REPOSITORIO/releases/latest/download/censo.apk`.

La app Android revisa ese enlace cuando tiene internet y muestra un aviso
"Hay una versión nueva" con un botón para descargarla.

Requisito único: dos secretos en el repositorio (Settings → Secrets and
variables → Actions): `CENSO_KEYSTORE_BASE64` y `CENSO_KEYSTORE_PASSWORD`.
La llave está en la carpeta `firma/`, que nunca se sube a GitHub.

También se puede construir a mano en Android Studio (abrir la carpeta `android/`,
Build → Build APK), pero ese APK no lleva la firma fija.

## Nube, usuarios y cierre del censo

Los datos se guardan en Supabase (proyecto `censo-comunitario`). La app sigue
funcionando sin señal: cada registro queda en el teléfono como "pendiente" y
sube solo cuando vuelve la conexión.

- **Primer uso:** la app pide crear el **administrador** (solo se puede una vez).
- **Roles:** censador (registra y ve solo lo suyo), manager (ve todo, resumen,
  gráficas y Excel; no edita) y admin (todo, más usuarios y cierre).
- **Usuarios:** el admin los crea en la pestaña Admin con usuario y clave.
  Puede cambiar claves, roles y desactivar a quien ya no participe.
- **Cerrar el censo:** pestaña Admin, "Cerrar ingreso de datos". La base de
  datos rechaza desde ese momento cualquier registro nuevo o cambio.
- **Excel:** pestaña Datos, archivo .xlsx con hojas Resumen, Viviendas y Personas.

Archivos del servidor en `supabase/`: `001_esquema.sql` (tablas y permisos) y
`functions/usuarios` (crear y administrar usuarios).

## Cómo se trabaja en el campo

1. Cada encuestador usa su teléfono y llena un registro por vivienda, con
   todas las personas que viven ahí.
2. Al final del día: pestaña **Datos** → *Respaldo completo (JSON)*.
3. Para juntar todo, en un solo equipo: **Datos** → *Importar* cada JSON.
   Los registros repetidos no se duplican.
4. **Datos** → *Excel (CSV)* da una fila por persona, lista para Excel.

Importante: si se borran los datos del navegador o se desinstala la app,
se pierden los registros. Exportar el respaldo JSON con frecuencia.

## Preguntas propias y exportación a medida

- **Admin → Preguntas del formulario**: el administrador crea preguntas nuevas (selección única, casillas de varias opciones, sí/no, texto, número o fecha), a la vivienda o a cada persona, y puede marcarlas obligatorias, ordenarlas, ocultarlas o borrarlas. Los censadores las ven al sincronizar.
- Las respuestas salen como columnas nuevas en el Excel completo, y las de selección única o sí/no también se pueden graficar en Resumen.
- **Datos → Exportación a medida** (manager y admin): elige columnas y filtros (por ejemplo edad mayor o igual a 18) y descarga solo eso en Excel. El botón de ejemplo arma "nombre, edad, teléfono y cédula de mayores de edad".
