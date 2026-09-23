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
5. **Configuración** (desplegable): límite de memoria Metal, contexto máximo, puerto,
   toggle de inicio automático. Los valores por defecto (28G de memoria, 64K de contexto)
   están pensados para convivir con un entorno de desarrollo normal (IDEs, navegador,
   opencode) en una Mac de 48GB — no acaparan toda la RAM disponible.
6. **Conectar** abre una terminal con el agente elegido ya apuntando al server local.
7. **WebUI** abre el chat embebido de Splash en el navegador.

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
```

## Limitaciones conocidas

- No hay telemetría de tok/s o uso de RAM en vivo dentro de la UI (se puede ver en el log
  de consola o vía el webui). Queda como posible mejora futura.
- `TerminalLauncher` siempre abre Terminal.app (vía AppleScript), no tu terminal por
  defecto (Warp, iTerm, etc.) — es la única terminal garantizada scriptable sin asumir
  qué tenés instalado.
- Sin tests automatizados; es una utilidad personal de un solo usuario.
