# BtoFolderLoop

Open-source native macOS utility. GPL-3.0-or-later. Initial release: preview.

## Product contract
Choose or drop one or multiple directories (or macOS folder aliases/symlinks resolved explicitly to real roots), inspect a complete preview, select candidates and explicitly approve moving only empty subdirectories to macOS Trash. Duplicate and overlapping roots are scanned only once. Batch execution is sequential, stops at an error/cancellation and journals each root independently. Every scan begins with all candidates deselected. Selection never expands to parents or children implicitly. Single-pass considers only initially empty leaves. Cascade includes only selected ancestors that become empty. Never remove any explicitly selected root, including nested ones, original shortcuts, files, symbolic links, packages, unreadable entries, or anything not in the approved subset. Never empty Trash. New or changed contents invalidate eligibility.

## Structure and commands
Swift Package targets: BtoFolderLoopCore (models/planner/executor and ports), BtoFolderLoopMac (native filesystem), BtoFolderLoopStorage (SQLite), BtoFolderLoopApp (SwiftUI). Sparkle 2.9.6 is pinned for signed application updates. Folder operations remain local; only public release checks, signed feeds and update downloads use the network. Never send folder paths, logs or system profiling.
`swift test`; `bash scripts/build-app.sh`; `python3 scripts/check-public.py`.

## Authority and safety
Announce changes and test only synthetic fixtures. User data, publication, signing credentials and destructive operations require their specific authorization. Never use permanent deletion as a Trash fallback. Preserve partial journals and fail closed. No automatic rollback: recovery uses the recorded Trash destinations and free original paths.
Local source -> tests -> commit -> authorized public repository -> verified release. No servers or deployments in this project. Public examples must be synthetic. No private paths, personal records, tokens, databases, or machine-specific governance in Git. The public v0.2.0 update (individual selection and application identity) is authorized at `btoaldas/BtoFolderLoop` on GitHub; v0.1.0 stays available. The v0.3.0 update (history/retention, signed updates and multiple-folder/shortcut inputs) is authorized for publication and local installation after verifying no folder operation is active. Future release authority must be established for its specific scope.

## Evidence and maintenance
Verify planning, filesystem failures, stale plans, no-file-loss, native Trash and SQLite persistence. UI smoke tests must cover preview/confirmation/results; a successful build alone is insufficient. Record reproducible results in docs/hitos. Update ROADMAP and dated bitacora on milestones. Known limits must be disclosed.

## Context economy
Use structural code indexing when available; inspect relevant symbols and small files before broader searches. Keep changes scoped and avoid dumping repository trees. Local tool configuration is untracked.

<!-- skill-anexos:navegacion-e2e-coherencia-20261025:begin -->
## Navegación E2E y acceso autorizado — regla vigente (2026-10-25)

Esta regla se aplica automáticamente a la navegación web y a las pruebas E2E web de este proyecto y sus agentes, skills y subdirectorios. En este ámbito prevalece sobre instrucciones anteriores incompatibles, como exigir un navegador visible, un perfil personal, una ruta fija de caché de otro sistema o el tecleo manual de credenciales disponibles.

- Aplicar los skills `playwright` y `chromium-headless`: Chromium interno de Playwright en modo headless, sin abrir ventanas ni depender de Chrome del usuario o de una extensión. Reutilizar el runtime, la configuración y las pruebas del proyecto; resolver el ejecutable con la API y comprobar los parámetros efectivos. Las pruebas nativas de escritorio o móvil conservan su herramienta específica. Si el usuario solicita expresamente su Chrome o su sesión, aplicar `chrome-browser` y los permisos de esa superficie.
- Si el usuario autoriza expresamente cuenta, destino y tarea autenticada, aplicar `acceso-web-autorizado` automáticamente: recuperar e introducir internamente la credencial pertinente de Obsidian, Llavero o la fuente local autorizada, o la que proporcione el usuario. No exigir invocación manual del skill ni volver a pedir su tecleo. Esta cláusula por sí sola no autoriza entrar a cuentas.
- Comprobar origen y cuenta antes de introducir y enviar credenciales; respetar MFA, CAPTCHA y permisos. No eludir una denegación. Máximo dos intentos; no exponer secretos en scripts, argumentos, registros, snapshots, capturas, trazas, repositorios ni informes. Para accesos reales prevalece la fuente autorizada vigente sobre literales heredados.
- El acceso conserva las autorizaciones específicas para envíos, publicaciones, firmas, pagos, borrados y cambios de datos o producción. Cerrar solo la sesión propia. La instalación global no demuestra que este proyecto pase sus pruebas: en otro equipo, cloud o CI comprobar skills, dependencias y navegador por separado; no copiar perfiles ni almacenes de credenciales por inferencia.

Para seleccionar Chromium completo, usar `channel="chromium"` con headless activo (por ejemplo, `headless=True` en Python o `headless: true` en JavaScript). El agente realiza internamente la navegación y las capturas de evidencia cuando la herramienta y el alcance estén autorizados; solicita intervención solo ante una autorización que falte, MFA, CAPTCHA, permisos o un recurso inaccesible. Esta precisión prevalece sobre ejemplos anteriores que deleguen al usuario abrir y capturar una página que el agente puede comprobar dentro del alcance autorizado.

Los procedimientos específicos de grabación o demostración de una interfaz solicitada conservan sus herramientas y permisos. Las comprobaciones internas y E2E web de esos repositorios siguen el carril anterior; los motores productivos existentes conservan su arquitectura.

<!-- skill-anexos:navegacion-e2e-coherencia-20261025:end -->
