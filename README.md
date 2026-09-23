# SplashBar

App nativa de barra de menú (SwiftUI `MenuBarExtra`) para gestionar
[Splash](https://inco.ai/blog/splash/), el motor de inferencia local para Apple Silicon.
Pensada para no competir por RAM con el propio LLM que administra: ~15-30MB en reposo,
sin runtime de por medio (nada de Electron).

## Qué resuelve

Splash trae CLI (`splash serve/claude/opencode/codex/hermes`) y un webui embebido que es
solo chat — no hay forma de gestionar modelos, memoria o contexto sin terminal. SplashBar
agrega la capa de gestión visual que falta:

- Listar modelos oficiales soportados (leído del catálogo que el propio Splash instala,
  así que un `brew upgrade splash` que agregue un modelo aparece solo).
- Descargar / borrar modelos del disco sin pisar el CLI.
- Cargar / detener el servidor de un modelo con un click.
- Configurar límite de memoria (Metal) y contexto máximo, con validación numérica y
  selector de unidad (K/M/G) — sin escribir flags a mano.
- Detectar si un modelo ya está corriendo (aunque lo hayas arrancado vos por consola)
  y mostrar sus specs activas: puerto, memoria, contexto.
- Confirmación antes de borrar un modelo (evita deletes accidentales).
- Errores de carga visibles en el header (texto rojo + botón para descartar).
- Atajos para conectar agentes al server activo: `opencode`, Claude Code, Codex, Hermes
  — cada uno abre en su propia ventana de Terminal, corriendo el wrapper `splash <agente>`.
- Abrir el webui de chat de Splash con un click.
- Iniciar con el login (macOS `SMAppService`, sin helper app aparte).
- Memoria y contexto por defecto calculados según la RAM real del equipo (no un número fijo
  igual para todas las Macs), con botón para restaurar esos recomendados en cualquier momento.
- Ventana "Acerca de" con versión, link al repo y al autor en GitHub, año y licencia.
- Sincronización automática del `"context"` declarado para el provider `splash` en
  `opencode.json`, leído del `/status` real del server — evita el error "prompt exceeds the
  context window" cuando cambiás el contexto acá y te olvidás de actualizar opencode a mano.

## Requisitos

- macOS 14+ (Sonoma o más nuevo), Apple Silicon.
- [Splash](https://inco.ai/blog/splash/) instalado vía Homebrew: `brew install incoai/tap/splash`.
- Xcode / Swift toolchain 6.4+ para compilar (`xcode-select -p` debe apuntar a un Xcode instalado).

## Compilar e instalar

```sh
git clone <este-repo>
cd SplashBar
./build-app.sh --install
```

Esto compila en modo release, empaqueta `SplashBar.app` (firma ad-hoc local) y lo copia a
`/Applications/SplashBar.app`. `SMAppService` (usado para "iniciar con el login") requiere
que la app viva en una ubicación estable como `/Applications` para persistir el registro
entre reinicios — por eso el flag `--install` en vez de dejarla corriendo desde el clon.

Sin `--install`, el script deja el bundle en `./SplashBar.app` para probar sin tocar
`/Applications`:

```sh
./build-app.sh
open SplashBar.app
```

## Uso

1. Abrí la app — aparece un ícono en la barra de menú (círculo que cambia de forma según
   el estado: detenido, bajando, cargando, activo, error).
2. Click en el ícono despliega el panel: lista de modelos, configuración, accesos rápidos.
3. **Bajar** un modelo lo descarga sin cargarlo al server. **Cargar** lo baja si hace falta
   y arranca `splash serve` con la memoria/contexto configurados.
4. El modelo activo se resalta con una card verde mostrando puerto, memoria y contexto
   reales con los que se lanzó.
5. **Configuración** (desplegable): límite de memoria Metal, contexto máximo (numérico +
   selector K/M/G), puerto, toggle de inicio automático, y botón "Restaurar recomendados".
   Los valores sugeridos se calculan de la RAM real del equipo (`RecommendedDefaults.swift`):
   se reserva el mayor entre 16GB o 30% del total para macOS + apps, el resto queda
   disponible para Splash; el contexto escala en tramos (32K/64K/128K/256K) según cuánta RAM
   total hay. En una Mac de 48GB da ~32G/64K; en una de 64GB, ~44G/128K.
6. **Conectar** abre una terminal con el agente elegido ya apuntando al server local.
7. **WebUI** abre el chat embebido de Splash en el navegador.
8. El botón ⓘ del footer abre "Acerca de" con versión, link al repositorio y al autor.

## Notas de implementación

- **Un modelo por proceso**: Splash sirve un solo modelo por instancia/puerto. Cambiar de
  modelo implica detener el server actual y levantar el otro — la app lo maneja
  automáticamente al apretar "Cargar" en un modelo distinto al activo.
- **Detección de servers externos**: si arrancaste `splash serve` a mano por fuera de la
  app, SplashBar lo detecta pegándole a `GET /v1/models` al abrir. En ese caso memoria y
  contexto se muestran como "auto" porque la app no controló ese lanzamiento — para ver
  las specs reales, detenelo y volvé a cargarlo desde la UI.
- **Memoria real vs. Activity Monitor**: Splash mapea los pesos del modelo con `mmap`;
  las páginas se "wirean" recién cuando el GPU las toca por primera vez (lazy loading).
  Es normal ver RAM/CPU/GPU bajos justo después de cargar un modelo si todavía no
  mandaste ninguna consulta — el consumo real aparece durante la generación, no al cargar.
- **Borrado real de disco**: los modelos instalados son symlinks desde
  `~/Library/Application Support/Splash/models/` hacia el cache real de Hugging Face
  (`~/.cache/huggingface/hub/`). Borrar desde la app resuelve el symlink y borra el
  snapshot real, liberando espacio de verdad (no solo el link).
- **Sincronización con opencode**: opencode declara un `limit.context` estático por modelo en
  su config — no tiene forma de preguntarle a un provider `openai-compatible` genérico cuál es
  su límite real. Splash sí lo expone gratis en `GET /status` → `maximum_context_tokens`, sin
  necesitar una inferencia. `OpencodeSync.swift` pega ese número en el bloque `"splash"` de
  `opencode.json` cada vez que un modelo queda listo (o se detecta uno ya corriendo), usando
  reemplazo de texto acotado por conteo de llaves — nunca un parse+rewrite completo del JSON,
  que reordenaría/reformatearía el resto de un archivo de config grande y editado a mano. Se
  puede desactivar o apuntar a otra ruta desde Configuración.

## Estructura

```
Sources/SplashBar/
  SplashBar.swift          entry point (@main, MenuBarExtra)
  ContentView.swift         UI del panel desplegable
  SplashController.swift    maneja el proceso `splash serve`, parsea su stdout, expone estado
  ModelCatalog.swift         lee el catálogo oficial de modelos + escanea instalados
  ModelsViewModel.swift      wrapper observable del catálogo para la UI
  SettingsStore.swift        persistencia de memoria/contexto/puerto/login-item
  SizeUnit.swift             enum K/M/G para los selectores de unidad
  SplashPaths.swift          resuelve rutas de Homebrew/Splash independiente del prefix
  TerminalLauncher.swift     abre Terminal.app y corre un comando (para "Conectar")
  LoginItemManager.swift     wrapper de SMAppService para iniciar con el login
  RecommendedDefaults.swift  calcula memoria/contexto sugeridos según la RAM del equipo
  AppInfo.swift              versión, build, URLs de repo/autor para la ventana Acerca de
  AboutView.swift            ventana "Acerca de SplashBar"
  OpencodeSync.swift         sincroniza el contexto real con opencode.json

Assets/
  icon-1024.png              fuente maestra del ícono (con alpha real)
  README.md                  cómo se generó y cómo regenerar el .icns

AppIcon.icns                 ícono compilado, referenciado desde Info.plist
LICENSE                      MIT
```

## Limitaciones conocidas

- No hay telemetría de tok/s o uso de RAM en vivo dentro de la UI (se puede ver en el log
  de consola o vía el webui). Queda como posible mejora futura.
- `TerminalLauncher` siempre abre Terminal.app (vía AppleScript), no tu terminal por
  defecto (Warp, iTerm, etc.) — es la única terminal garantizada scriptable sin asumir
  qué tenés instalado.
- Sin tests automatizados; es una utilidad personal de un solo usuario.
