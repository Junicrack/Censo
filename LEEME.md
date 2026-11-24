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

## Cómo se trabaja en el campo

1. Cada encuestador usa su teléfono y llena un registro por vivienda, con
   todas las personas que viven ahí.
2. Al final del día: pestaña **Datos** → *Respaldo completo (JSON)*.
3. Para juntar todo, en un solo equipo: **Datos** → *Importar* cada JSON.
   Los registros repetidos no se duplican.
4. **Datos** → *Excel (CSV)* da una fila por persona, lista para Excel.

Importante: si se borran los datos del navegador o se desinstala la app,
se pierden los registros. Exportar el respaldo JSON con frecuencia.
