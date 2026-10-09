# Quini App — Roadmap de implementación

Este archivo es la **fuente única de tareas por fase**. Describe qué construir, en qué orden y cómo comprobar que funciona. Las reglas del producto están en [requisitos](01-requirements.md) y [reglas de negocio](02-business-rules.md); el [modelo de datos](03-data-model.md) y el [stack](04-tech-stack.md) completan el contexto.

## Ubicación, nombre y mantenimiento

Se conserva **`context/05-roadmap.md`**: ya pertenece a la documentación del proyecto, mantiene el orden de lectura y evita romper referencias. `ROADMAP.md` en la raíz o `docs/roadmap.md` serían alternativas razonables, pero no son necesarias para este repositorio. No se creará una segunda copia del plan.

El README de la raíz enlaza este documento para hacerlo fácil de encontrar. La documentación oficial de GitHub explica el papel del README como punto de entrada y recomienda enlaces relativos a otros archivos; no prescribe un nombre reservado para roadmaps.

Fuentes consultadas:

- [GitHub: About the repository README file](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes): descubrimiento de documentación y enlaces relativos.
- [PrimeNG: Installation](https://primeng.org/installation): integración mediante providers, tema e imports de componentes individuales.

### Cómo usar este plan

- `[x]` significa entregado y comprobado en el repositorio, o confirmado expresamente como información externa. `[ ]` significa pendiente, incluso si existe un diseño.
- Los identificadores `F1.1`, `F2.3`, etc. permiten referenciar tareas en commits o incidencias. No requieren introducir una herramienta de gestión adicional.
- Cada fase tiene objetivo, dependencias, tareas y criterios de aceptación. No se cierra por tener la UI si faltan permisos, integridad o pruebas.
- Al terminar una tarea, marcarla y registrar aquí cualquier cambio relevante de alcance. Mantener los requisitos y reglas sincronizados cuando cambie una decisión de producto.
- Las rutas propuestas son orientativas; no hay que crear carpetas vacías ni abstracciones genéricas para cumplir el plan.
- No hay fechas ni estimaciones cerradas: el progreso se mide con entregables verificables.

## Estado real de partida

| Elemento | Estado |
|---|---|
| Requisitos y reglas principales | Fase 0 cerrada; decisiones confirmadas y ejemplos de aceptación documentados |
| Angular 21 standalone, routing, TypeScript estricto y Tailwind 4 | Base configurada |
| Cliente Supabase y configuración pública en runtime | Preparados; no equivalen a un flujo de auth implementado |
| Proyecto Supabase | Proyecto actual autorizado como desarrollo remoto (Postgres 17.6); baseline aplicado e historial sincronizado |
| Esquema SQL | Baseline y migraciones F1.4/F1.5 aplicados/versionados; 104 pruebas pgTAP en 3 suites repetidas y lint correctos; Docker no obligatorio |
| RLS | Habilitado en las nueve tablas; denegación inicial validada con roles anon/authenticated; políticas funcionales pendientes |
| PrimeNG | Elegido; pendiente de instalar |
| Pantallas y rutas funcionales | Pendientes; solo existe la portada inicial |
| Resend | Endpoint base en `api/send-email.mjs`; no protegido ni integrado con jornadas |
| Vercel | Configuración de build y fallback SPA; despliegue funcional completo por validar |
| Pruebas | 2 Angular, 9 del runner y 104 SQL (15 baseline + 62 integridad + 27 virtual) correctas; pendiente ampliar funcionalidades, permisos y concurrencia de RPC |

## Entorno de ejecución acordado

- **Frontend local + Supabase remoto de desarrollo**; la réplica local con Docker es opcional, no un bloqueo del roadmap.
- El proyecto actual está destinado a desarrollo. `supabase/development.json` y el enlace del CLI deben coincidir antes de desplegar/probar/hacer lint.
- Validación SQL sin Docker mediante `pnpm db:test`: fixtures repetidos dentro de una transacción con rollback, resultados TAP completos y comprobación del estado posterior. No se renuncia a probar las reglas o permisos.
- No ejecutar resets remotos ni pruebas con fixtures contra producción. Crear un proyecto de producción separado antes del lanzamiento, con variables Auth/Storage/Vercel propias.
- Las migraciones aplicadas son inmutables. Consultar historial/inventario y plan antes de cada despliegue; no usar cambios manuales del Dashboard como sustituto de migraciones.
- Procedimiento y evidencia: [supabase/README.md](../supabase/README.md).

## Orden y dependencias

| Fase | Entregable | Estado | Depende de |
|---|---|---|---|
| 0 | Definición de producto y decisiones | Completada | — |
| 1 | Backend seguro, auth, perfiles y base de UI | Parcial / siguiente prioridad | 0 |
| 2 | Administración de catálogos, usuarios e invitaciones | Pendiente | 1 |
| 3 | Temporada inicial y creación/inicio de jornadas | Pendiente | 1, 2 |
| 4 | Envío y consulta de pronósticos | Pendiente | 3 |
| 5 | Resultados, duelos y correcciones administrativas | Pendiente | 3, 4 |
| 6 | Clasificación, estadísticas y ciclo de temporadas | Pendiente | 5 |
| 7 | Recordatorios por correo seguros | Pendiente | 1, 3; puede adelantarse tras estas fases |
| 8 | Validación integral, pulido y lanzamiento | Pendiente | 1–7 |

El motor de puntuación y la clasificación ya tienen reglas definidas, pero se implementan en sus fases funcionales, no como prerrequisito de los primeros CRUDs. Responsive, accesibilidad, seguridad y pruebas se trabajan en todas las fases; la fase 8 no es su primera aplicación.

## Fase 0 — Definición de producto y decisiones

**Estado:** completada. Las decisiones fueron confirmadas por el desarrollador y los ejemplos están en [validación de fase 0](06-phase-0-acceptance.md). La validación funcional no equivale a tener motor SQL o RLS implementados.

**Objetivo:** disponer de un contrato de comportamiento claro, sin confundir decisiones de producto con propuestas técnicas.

### Tareas

- [x] **F0.1 — Documentar alcance y roles.** Juego recreativo entre amigos; 5 partidos comunes por jornada; admins que también pueden competir; cierre manual; histórico conservado.
- [x] **F0.2 — Definir puntuación y estadísticas.** Victoria/empate/derrota, excepciones por ausencia de pronóstico y penalización de 0 aciertos y 5 fallos.
- [x] **F0.3 — Incorporar las aclaraciones de producto.** Desempate de tres o más por aciertos totales, rival virtual por baja, correcciones del admin sin límite temporal y PrimeNG como UI.
- [x] **F0.4 — Validar ejemplos de desempate antes de F6.** Confirmado: dos jugadores usan balance de victorias directas; tres o más usan aciertos de temporada sin reiniciar el directo al quedar dos. Igualdad completa: posiciones compartidas `1, 2, 2, 4`, con username solo para orden visual. Ejemplos A–E documentados y aritmética revisada en `06-phase-0-acceptance.md`.
- [x] **F0.5 — Concretar el momento efectivo de una baja antes de F2/F3.** Confirmado: la sustitución virtual solo se aplica a jornadas creadas después de la baja. Jornadas existentes ABIERTA/EN_CURSO/FINALIZADA conservan jugadores reales y lo enviado; el desactivado pierde acceso protegido y nuevos envíos propios. Escenarios temporales documentados para implementar el límite transaccional.
- [x] **F0.6 — Confirmar los casos extremos antes de F5.** Confirmado: real sin envío contra virtual recibe 0 puntos y 5 fallos. Doble virtual: conservar duelo no puntuable 0/0, sin estadísticas ni clasificación para nadie. Matriz de aceptación actualizada.
- [x] **F0.7 — Definir visibilidad de datos antes de F1/F4.** Confirmado: juego e histórico solo para usuarios autenticados activos. ABIERTA: pronósticos propios; desde EN_CURSO: todos los del grupo; admin activo puede revisarlos siempre. Identidad ajena limitada a username/avatar, sin correo ni perfil privado; invitaciones/auditoría exclusivas del admin. Matriz y escenarios API documentados.

### Criterios de aceptación

- Las reglas principales están sincronizadas en `01-requirements.md` y `02-business-rules.md`.
- F0.4–F0.7 están confirmadas, con ejemplos de aceptación consistentes; ya no quedan decisiones pendientes dentro de esta fase.
- No se amplía el alcance con apuestas, pagos, APIs deportivas, chat o solicitudes de cambio automatizadas.

## Fase 1 — Backend seguro, autenticación y base de UI

**Objetivo:** permitir que un usuario invitado entre y gestione su perfil, con permisos fiables y una estructura Angular mínima reutilizable.

**Dependencias:** fase 0 completada; aplicar la matriz de visibilidad confirmada en F0.7 al implementar las políticas de lectura.

### 1A. Esquema y entorno Supabase

- [x] **F1.1 — Diseñar las entidades iniciales.** Perfiles, invitaciones, equipos, competiciones, temporadas, jornadas, partidos, predicciones y duelos en `03-data-model.md` y `schema.sql`.
- [x] **F1.2 — Preparar infraestructura de desarrollo.** Angular/Tailwind local, singleton Supabase, generación de `public/env.js` y configuración Vercel disponibles. Proyecto Supabase remoto enlazado; Docker opcional por restricciones del equipo corporativo.
- [x] **F1.3 — Verificar y versionar el esquema.** Cerrada: remoto inspeccionado inicialmente vacío en Postgres 17.6; baseline `20261005212317_initial_schema.sql` aplicado mediante migraciones e historial local/remoto coincidente. CLI 2.119.0 fijado; inventario, fixtures reproducibles y runner sin Docker con guardia de proyecto de desarrollo. 15 comprobaciones pgTAP correctas en dos ejecuciones, seed cargado dos veces por transacción sin duplicados, datos/grants/pgTAP revertidos; lint sin errores y segundo despliegue no-op. Pasan 9 tests del runner, 2 Angular y build. Esta validación remota reemplaza el reset local, sin ejecutar resets remotos. Evidencia/procedimiento en [supabase/README.md](../supabase/README.md).
- [x] **F1.4 — Reforzar integridad y preservación del histórico.** Cerrada: migración `20261009133127_integrity_and_history.sql` aplicada a desarrollo, sin modificar baseline. 12 FK RESTRICT; bloqueo DELETE/TRUNCATE y de reasignaciones históricas; soft delete conservado; CHECKs de número/fechas/aciertos/puntos y cálculo completo de duelos; transiciones monotónicas y guardias de nueva actividad con bloqueos de padres. Correcciones de pronósticos/derivados existentes siguen permitidas en temporadas cerradas por la integridad (autorización/auditoría/recálculo son F1.8/F5). Pasan 62 nuevos casos + 15 baseline, repetidos, lint sin errores, runner/Angular/build correctos. Plan de operaciones atómicas/participación única en [supabase/integrity.md](../supabase/integrity.md); implementación completa y pruebas de concurrencia en F3/F4/F5.
- [x] **F1.5 — Diseñar e implementar la persistencia del rival virtual.** Cerrada: migración `20261009140144_virtual_duel_participants.sql`; un lado se representa con `player_*_id IS NULL` y `player_*_replaced_id` FK al perfil inactivo sustituido. Real y virtual son excluyentes por lado; no se crea Auth ficticio. Trigger controlado comprueba perfiles activos/inactivos al insertar y bloquea sus filas; el reemplazo queda inmutable y reactivar al perfil no cambia duelos existentes. Los CHECKs garantizan cero aciertos/puntos virtuales e incluyen doble virtual no puntuable; no calculan el score ni las estadísticas. Pasan 27 casos nuevos, 62 de F1.4 + 15 baseline (104 totales), repetidos; incluyen orden de triggers y guardia SECURITY DEFINER no invocable por roles API. Lint/build y pruebas frontend correctos. Operación F3 debe fijar la baja concurrente antes de publicar; F1.8 protegerá la lectura de columnas de reemplazo; scoring/UI quedan en F5/F4.

### 1B. Registro, perfiles y autorización

- [ ] **F1.6 — Implementar registro seguro por invitación.** Validar el código en servidor y consumirlo una sola vez con protección frente a registros concurrentes. Vincular perfil y cuenta Auth; impedir crear cuentas utilizables saltándose la UI y tratar errores sin dejar invitaciones consumidas o perfiles incoherentes. No aceptar `role` o `activo` enviados por el cliente.
- [ ] **F1.7 — Preparar el primer admin.** Definir un procedimiento manual/servidor reproducible para asignar el rol inicial fuera del registro normal. Nunca publicar credenciales o claves privilegiadas.
- [ ] **F1.8 — Implementar RLS y permisos de funciones.** Matriz por tabla para `anon`, player activo, admin activo y usuario desactivado; operaciones SELECT/INSERT/UPDATE/DELETE según requisitos. Proteger columnas privilegiadas con permisos de columna o RPC controladas, además de RLS. Evitar políticas recursivas al consultar el rol y revisar `SECURITY DEFINER`, `search_path` y grants.
- [ ] **F1.9 — Implementar estado de sesión y rutas.** Servicio de auth con signals, restauración de sesión, cambios de sesión, login/logout y guards de usuario/admin. Mostrar carga inicial y redirigir correctamente; los guards no sustituyen a los permisos del backend.
- [ ] **F1.10 — Crear registro, login y recuperación de contraseña.** Formularios con validaciones, errores comprensibles y prevención de envíos duplicados. Configurar callback y redirects en Auth del proyecto remoto para `localhost:4200` y Vercel; `config.toml` solo configura el stack local opcional. Comprobar el flujo de enlace caducado o inválido.
- [ ] **F1.11 — Crear edición del perfil propio.** Username, avatar y correo; usar Auth para cambiar email y mantener `profiles.email` sincronizado con el cambio efectivo, no con un valor arbitrario del cliente. Rol de solo lectura y sin botón de baja para players.
- [ ] **F1.12 — Configurar Storage y sus permisos.** Escudos públicos y estrategia de avatares documentada; escrituras de escudos solo admin y de avatar solo propietario/admin según el flujo. Validar tipo/tamaño, rutas de objetos y borrado/sustitución de imágenes sin romper referencias.

### 1C. PrimeNG y estructura frontend

- [ ] **F1.13 — Instalar PrimeNG compatible con Angular 21.** Comprobar peer dependencies, instalar la librería y el paquete de temas correspondiente a esa versión, configurar `providePrimeNG` y preset Aura o equivalente. Importar por componente; iconos e integración extra con Tailwind solo si se necesitan. Verificar build y pruebas antes de dar la instalación por válida.
- [ ] **F1.14 — Crear el shell mobile-first.** Navegación del player y acceso al menú admin condicionado al rol; encabezado, contenido, estados de carga/error/vacío y notificaciones. Tailwind para layout; PrimeNG styled para controles. Un admin conserva también el acceso a jugar.
- [ ] **F1.15 — Organizar por funcionalidades.** Mantener `core/` para auth/config/Supabase y agrupar pantallas en `features/` según necesidad. Servicios pequeños, tipado de respuestas y tipos de base de datos generados tras las migraciones; signals/computed para estado y `rxResource()` donde simplifique lecturas. Sin NgRx ni repositorios genéricos prematuros.

### Criterios de aceptación

- Registro válido crea una cuenta y perfil coherentes; código inválido/usado o dos usos simultáneos no permiten saltarse la invitación.
- Login, logout, recuperación y edición de perfil funcionan; un player no puede convertirse en admin ni reactivarse con una petición directa.
- Un desactivado no puede participar en operaciones protegidas, incluso con una sesión previamente emitida.
- Las pruebas de RLS usan roles reales de cliente; no basta con probar como `service_role`.
- Escudos y avatares respetan permisos; no hay secretos privados en `public/env.js` ni en el bundle.
- PrimeNG y shell funcionan en móvil y PC; build y pruebas frontend pasan.

## Fase 2 — Administración de equipos, competiciones, usuarios e invitaciones

**Objetivo:** proporcionar al admin los catálogos y participantes necesarios para preparar jornadas.

**Dependencias:** fase 1; aplicar el límite temporal de bajas confirmado en F0.5.

### Tareas

- [ ] **F2.1 — Crear el área de administración.** Rutas protegidas, navegación por entidades y patrón coherente de tabla/listado, detalle y formulario. Reutilizar solo lo que se repita de verdad, no un CRUD universal configurable.
- [ ] **F2.2 — Implementar equipos.** Listar, buscar, crear y editar nombre/escudo; subir y sustituir imagen con feedback. Permitir equipos de cualquier liga y selecciones. Activar/desactivar sin borrar el histórico; indicar registros inactivos y errores de Storage.
- [ ] **F2.3 — Implementar competiciones.** Crear/editar nombres, controlar duplicados y activar/desactivar. Las competiciones inactivas permanecen en partidos antiguos pero no se ofrecen para nuevos partidos.
- [ ] **F2.4 — Implementar usuarios.** Listado y detalle con rol/estado; cambios de rol por admins. Desactivar sin borrar Auth/perfil/pronósticos. Definir salvaguarda para no perder el último admin activo y no aplicar una baja histórica de forma retroactiva.
- [ ] **F2.5 — Aplicar los efectos de las bajas.** Registrar el momento efectivo y bloquear acceso protegido/nuevos envíos. No cambiar participantes de jornadas ya publicadas, incluso abiertas/en curso; mantener el cómputo de lo enviado. Aplicar rival virtual únicamente en jornadas creadas después y mostrar este alcance al admin. No reasignar pronósticos ni estadísticas antiguas a `jugador_undefined`.
- [ ] **F2.6 — Gestionar invitaciones.** Generar códigos desde el servidor con autorización admin; listar disponibles/usados y facilitar copia. No permitir reutilización ni lectura del catálogo por players/anon. Mantener el alcance de códigos de un solo uso; expiración y cuotas solo si se deciden después.
- [ ] **F2.7 — Completar la experiencia de formularios.** Validaciones, confirmaciones de desactivación, indicadores de guardado, búsqueda y estados vacíos. Los errores no deben dejar la tabla desactualizada ni perder el formulario.
- [ ] **F2.8 — Probar permisos e histórico.** Intentar CRUDs como player y usuario desactivado; comprobar que cambios de nombre/estado no borran partidos, duelos o pronósticos antiguos.

### Criterios de aceptación

- Admin puede mantener catálogos, usuarios e invitaciones desde PC y móvil; player no puede hacerlo ni por peticiones directas.
- No se seleccionan equipos/competiciones inactivos para jornadas nuevas, pero se conservan las referencias antiguas.
- Desactivar un usuario conserva lo enviado y produce solo los efectos futuros acordados.
- Cualquier fallo de guardado o subida se comunica y permite reintentar sin duplicados.

## Fase 3 — Temporada inicial, creación e inicio de jornadas

**Objetivo:** publicar una jornada válida con cinco partidos y duelos completos, y cerrarla para pronósticos mediante una acción admin.

**Dependencias:** fases 1 y 2; F0.5 y representación virtual definida.

### Tareas

- [ ] **F3.1 — Crear/seleccionar la temporada inicial.** Flujo mínimo admin para una temporada activa y su nombre/fechas; decidir y garantizar si solo puede existir una activa. La gestión completa de cierre e histórico se entrega en F6. No crear jornadas en temporadas finalizadas.
- [ ] **F3.2 — Crear el formulario de los cinco partidos.** Selección de local, visitante y competición activos; equipos distintos; validación de exactamente cinco. Incorporar un orden persistente de los partidos para que admin y players vean la misma secuencia.
- [ ] **F3.3 — Crear emparejamientos.** Selección manual de participantes reales activos, incluidos admins que compitan; cada participante aparece una sola vez y no juega contra sí mismo. Cobertura completa del grupo participante y rival virtual únicamente cuando corresponda a una baja anterior a crear la jornada, no como descanso arbitrario. Representar un doble virtual usando los dos lados `player_id NULL` con referencias sustituidas; el RPC de F3 decide la asignación tras la baja y las reglas de F5 lo resuelven como no puntuable.
- [ ] **F3.4 — Publicar de forma transaccional.** Guardar jornada, cinco partidos y duelos en una única operación autorizada, siguiendo el plan de F1.4 en `supabase/integrity.md`. Validar cobertura/participación única entre columnas A/B y exactamente cinco partidos en servidor; un error revierte todo. Bloquear los padres de forma consistente y limitar escrituras directas que eludan el RPC. Proteger número único por temporada y evitar duplicados por doble clic/reintentos. Los triggers actuales no garantizan por sí solos la publicación completa.
- [ ] **F3.5 — Delimitar edición estructural.** Definir antes de habilitarla cuándo se pueden cambiar equipos, partidos o emparejamientos de una jornada publicada. Respetar identidades/adscripciones inmutables de F1.4 y el bloqueo de cambios de equipos/competición al haber pronósticos o comenzar. MVP: creación y consulta; si se decide permitir otras ediciones, añadir una operación/migración acotada, no desactivar guardias ni reescribir histórico.
- [ ] **F3.6 — Implementar `ABIERTA → EN_CURSO`.** Acción admin con confirmación, fecha efectiva y comprobación de estado/temporada. Serializarla con los envíos de predicciones para que no exista una ventana de escritura tardía.
- [ ] **F3.7 — Mostrar jornada y duelo.** Listado/detalle, cinco partidos, estado y rival del usuario; lista admin de quién ha enviado o falta. Mostrar `jugador_undefined` como rival virtual, no como una cuenta rota.
- [ ] **F3.8 — Preparar el recordatorio sin enviar todavía.** Reservar la acción opcional y el identificador de jornada para F7. La creación funciona sin servicio de correo; no duplicar aquí la integración de Resend.

### Criterios de aceptación

- No se publica una jornada con 4/6 partidos, equipos idénticos, participantes repetidos ni duelos incompletos.
- Fallar a mitad de la creación no deja una jornada parcial visible.
- Todos los participantes ven los mismos cinco partidos y un duelo inequívoco.
- Solo un admin inicia la jornada; a partir de ese cambio no entra ningún primer envío de player.

## Fase 4 — Pronósticos de players

**Objetivo:** permitir un único envío completo de 1X2 por jornada abierta y consultar lo enviado.

**Dependencias:** fase 3 y visibilidad de pronósticos acordada en F0.7.

### Tareas

- [ ] **F4.1 — Crear el formulario de juego.** Cinco partidos con escudos/nombres/competición, controles 1/X/2 claros y accesibles para móvil. Mostrar rival y estado; exigir una elección en cada partido.
- [ ] **F4.2 — Implementar envío atómico en servidor.** Comprobar identidad, participación real, perfil activo, temporada/jornada y ausencia de envío previo. Guardar exactamente sus cinco partidos juntos, sin `player_id` ajeno ni partidos duplicados/externos. Seguir el plan de F1.4: bloquear jornada, revalidar estado y serializar con inicio/doble envío; limitar escrituras directas fuera del RPC. La unicidad match/player y la guardia INSERT de estado no sustituyen el formulario completo.
- [ ] **F4.3 — Bloquear cambios del player.** Confirmación previa al envío, recibo/resumen posterior y controles de solo lectura al enviarse o cerrarse la jornada. Impedir UPDATE/DELETE mediante llamadas directas, no únicamente con botones deshabilitados.
- [ ] **F4.4 — Mostrar ausencias y resultados.** Distinguir formulario no enviado de uno enviado con cero aciertos. Antes de resolver, no mostrar ausencia como cinco fallos ya computados. Tras resolver, mostrar aciertos/fallos y puntos calculados.
- [ ] **F4.5 — Cubrir el rival virtual.** Mismo formulario y obligación de pronosticar; explicar que con cero aciertos enviados obtiene un punto, no una victoria automática.
- [ ] **F4.6 — Probar errores y permisos.** Envío incompleto, conexión fallida, reintento, acceso a predicciones ajenas, jugador fuera de duelo, desactivado y cierre concurrente.

### Criterios de aceptación

- Cada participante tiene cero o cinco predicciones por jornada, nunca un envío parcial.
- Un player no puede modificar/borrar un envío ni insertar después de `EN_CURSO`.
- La UI comunica claramente que el envío es definitivo para el player y mantiene una consulta fiable de lo guardado.
- La información del rival respeta la política de visibilidad definida.

## Fase 5 — Resultados, motor de puntuación y correcciones

**Objetivo:** resolver jornadas y corregir pronósticos con resultados reproducibles y consistentes, también en histórico.

**Dependencias:** fases 3 y 4; aplicar los casos extremos confirmados en F0.6.

### Tareas

- [ ] **F5.1 — Crear entrada de resultados manuales.** Pantalla admin para los cinco resultados 1X2. Permitir guardar progreso sin resolver duelos hasta que todos estén completos; impedir que un player cambie resultados.
- [ ] **F5.2 — Implementar el motor en servidor.** Calcular `acierto`, totales y fallos; resolver jugadores reales con las reglas de ausencia; tratar aparte el rival virtual. Derivar fallos de no enviados sin fabricar pronósticos falsos.
- [ ] **F5.3 — Resolver la jornada de forma atómica e idempotente.** Con los cinco resultados, rellenar resultado/aciertos/puntos de cada duelo y pasar a `FINALIZADA`. Sobrescribir valores derivados al recalcular, no sumarlos sobre los anteriores. Bloquear carreras con otras correcciones.
- [ ] **F5.4 — Implementar corrección administrativa de pronósticos.** Admin puede editar lo enviado sin solicitud ni límite de estado, incluso en temporada cerrada. Confirmación explícita del impacto y registro de admin, fecha y valores anteriores/nuevos; no exigir reabrir la jornada para players.
- [ ] **F5.5 — Recalcular datos afectados.** Una corrección en una jornada resuelta actualiza aciertos, fallos, resultado/puntos del duelo y consultas de clasificación/estadísticas. Una corrección antes de los resultados no debe adelantar puntos. No invalidar los otros cuatro pronósticos del formulario.
- [ ] **F5.6 — Acordar correcciones adicionales.** Antes de habilitar cambios de resultados reales ya finalizados o introducir un envío completo para quien no pronosticó, definir expresamente esos permisos y su recálculo; la autorización confirmada cubre corregir pronósticos, no inventa estos flujos.
- [ ] **F5.7 — Mostrar el resultado de jornada.** Comparativa de pronósticos/aciertos y puntos de ambos lados; indicadores claros de ausencia y rival virtual. Permitir al admin revisar errores de resolución sin ocultarlos.
- [ ] **F5.8 — Automatizar pruebas del motor.** Cubrir la matriz siguiente, ausencia penalizada, corrección tras finalizar y recálculo repetido. Validar lógica SQL y permisos, no solo funciones de frontend.

### Matriz mínima de puntuación

Los escenarios de jugadores reales se prueban también intercambiando A/B. Para quien no envía siempre son 0 aciertos y 5 fallos.

| Duelo | Envíos | Aciertos | Puntos | Verificación |
|---|---|---|---|---|
| Real A vs real B | Ambos | 4 / 2 | 3 / 0 | Victoria normal; fallos 1 / 3 |
| Real A vs real B | Ambos | 0 / 0 | 1 / 1 | Empate con cinco fallos cada uno |
| Real A vs real B | Solo A | 0 / 0 | 3 / 0 | Victoria automática por ausencia real |
| Real A vs real B | Ninguno | 0 / 0 | 0 / 0 | No hay empate puntuable |
| Real A vs virtual | Solo A | 2 / 0 | 3 / 0 | Virtual no suma ni aparece en standings |
| Real A vs virtual | Solo A | 0 / 0 | 1 / 0 | Empate especial, no victoria automática |
| Real A vs virtual | Ninguno | 0 / 0 | 0 / 0 | Real: 5 fallos; no empate puntuable |
| Virtual vs virtual | Ninguno | 0 / 0 | 0 / 0 | Conservar duelo no puntuable; sin estadísticas para nadie |

### Criterios de aceptación

- Sin los cinco resultados no hay jornada resuelta ni puntos provisionales contabilizados como definitivos.
- La matriz pasa y diferencia ausencia real de rival virtual.
- Recalcular dos veces produce exactamente el mismo estado y clasificación.
- Corregir un pronóstico en histórico actualiza el duelo y estadísticas, registra el cambio y no concede escritura ordinaria a players.
- Un cambio de `activo` actual no transforma retrospectivamente duelos históricos.

## Fase 6 — Clasificación, estadísticas y temporadas

**Objetivo:** consultar posiciones correctas por temporada y conservar el histórico al empezar otra.

**Dependencias:** fase 5; F0.4 validada.

### Tareas

- [ ] **F6.1 — Implementar la clasificación SQL.** Vista/función derivada de duelos resueltos, filtrada por temporada. Incluir participantes sin puntos, mantener jugadores desactivados que participaron y excluir rival virtual. Evitar joins que multipliquen puntos o mezclen temporadas.
- [ ] **F6.2 — Implementar la cascada de desempates.** Para dos, balance de victorias directas; para tres o más, total de aciertos de temporada sin restar fallos. Continuar con diferencia aciertos/fallos y jornadas ganadas sin reiniciar el directo en subgrupos de dos. Si una pareja no se enfrentó, seguir la cascada. Igualdad completa: posición compartida con saltos (`1, 2, 2, 4`), username solo para orden visual. Automatizar los ejemplos A–E de `06-phase-0-acceptance.md`.
- [ ] **F6.3 — Derivar estadísticas completas.** Puntos, duelos ganados/empatados/perdidos y participación, aciertos, fallos y enfrentamientos. No contar el 0/0 por doble ausencia como empate deportivo por defecto; distinguir resultado no puntuable. Duelo ganado al virtual cuenta como victoria del jugador real; el virtual no tiene ficha estadística.
- [ ] **F6.4 — Crear tabla y detalle del player.** Tabla legible en móvil y PC, explicación de criterios y navegación a jornadas/estadísticas. Consultas con estados de carga/error/vacío y permisos acordados.
- [ ] **F6.5 — Implementar cierre de temporada.** Acción admin con confirmación y fecha de fin; comprobar jornadas pendientes de resolver y tratar explícitamente ese bloqueo antes del cierre. Detener nuevas jornadas/envíos; conservar consulta y excepciones de corrección admin.
- [ ] **F6.6 — Crear nueva temporada e histórico.** Nueva clasificación desde cero, sin duplicar ni borrar resultados anteriores. Selector de temporada y consultas aisladas; aprovechar el flujo mínimo de creación de F3 sin mantener dos implementaciones.
- [ ] **F6.7 — Probar clasificación y aislamiento.** Empates de dos con múltiples encuentros, grupos de tres/cuatro, igualdad en aciertos, ausencia con cinco fallos, igualdad completa, bajas, virtual y correcciones en temporada cerrada. Verificar que nueva temporada no modifica la anterior.

### Criterios de aceptación

- Clasificación coincide con ejemplos calculados a mano y responde correctamente a correcciones.
- Fallos por ausencia participan en la diferencia; no se confunde total de aciertos con esa diferencia en empates múltiples.
- Temporadas cerradas son consultables y no admiten actividad ordinaria; las correcciones admin quedan trazadas.
- Jugadores desactivados conservan su historial y el virtual nunca ocupa una posición.

## Fase 7 — Recordatorios por correo

**Objetivo:** enviar recordatorios opcionales de jornadas abiertas sin exponer un servicio de envío arbitrario.

**Dependencias:** fases 1 y 3. Puede desarrollarse antes de F5/F6 si interesa probarlo pronto.

### Tareas

- [ ] **F7.1 — Proteger el endpoint existente.** Reutilizar `api/send-email.mjs` en Vercel. Verificar token Supabase y rol admin activo en servidor; rechazar usuarios anónimos/players/desactivados. No confiar en un rol enviado en el payload ni crear otra Edge Function para lo mismo.
- [ ] **F7.2 — Restringir el contrato al recordatorio.** Recibir un identificador de jornada y obtener asunto, contenido y destinatarios autorizados desde servidor; no aceptar libremente correos, HTML o asuntos de cualquier cliente. Escapar valores interpolados y no exponer la lista de emails.
- [ ] **F7.3 — Configurar Resend.** Dominio/remitente verificados y variables privadas en Vercel. Respetar límites del proveedor y tamaño del grupo; revisar el límite actual de diez destinatarios y agrupar sin revelar direcciones de amigos entre sí.
- [ ] **F7.4 — Integrar la acción admin.** Opción de enviar tras crear la jornada y acción manual de recordatorio. El fallo del correo no revierte una jornada creada correctamente; mostrar resultado y permitir reintento seguro.
- [ ] **F7.5 — Añadir protección mínima de abuso/reintentos.** Límite de frecuencia y registro de envíos suficiente para evitar duplicados accidentales. No incorporar colas complejas para este grupo pequeño; documentar tratamiento de errores y resultados parciales.
- [ ] **F7.6 — Evaluar SMTP de Auth.** Configurar Resend como SMTP de Supabase si se necesita para producción. Es opcional y distinto del endpoint de recordatorios; verificar entrega de recuperación/confirmación y límites reales.
- [ ] **F7.7 — Probar el flujo.** Solo admin puede enviar; solo destinatarios autorizados; secretos ausentes del navegador; errores de configuración/proveedor con mensajes seguros; botón doble y reintento no producen una tormenta de mensajes.

### Criterios de aceptación

- Ninguna petición pública puede convertir el endpoint en un relé de correo arbitrario.
- Recordatorio llega con enlace a la jornada y remitente válido; las direcciones no se revelan entre destinatarios.
- Crear una jornada no depende de disponibilidad de Resend y el admin conoce el estado del envío.

## Fase 8 — Validación integral, pulido y lanzamiento

**Objetivo:** publicar un MVP utilizable por el grupo, con operación sencilla y sin fallos críticos conocidos.

**Dependencias:** fases 1–7. El SMTP opcional no bloquea el lanzamiento si Auth funciona con la configuración de correo elegida.

### Tareas

- [ ] **F8.1 — Recorrer el flujo completo.** Admin crea catálogos/temporada/jornada; usuarios se registran, pronostican, reciben recordatorio, consultan resultados/clasificación; admin cierra y abre nueva temporada. Incluir corrección posterior y rival virtual.
- [ ] **F8.2 — Revisar responsive y accesibilidad.** Móvil como uso principal y PC para mantenimiento: navegación, tablas, formularios, touch targets, foco, teclado, etiquetas, contraste, estados deshabilitados y mensajes de error. No depender solo del color para 1/X/2 o aciertos.
- [ ] **F8.3 — Ejecutar pruebas y build.** `pnpm test --watch=false`, `pnpm run test:db-runner`, `pnpm db:test`, `pnpm run db:lint:dev` y `pnpm run build`; comprobar el build Vercel con variables públicas de prueba (`pnpm run build:vercel`). Ampliar smoke tests y pruebas SQL/RLS sobre desarrollo remoto, con rollback y sin fixtures en producción. CI mínima si se habilita; no marcar completo con fallos pendientes.
- [ ] **F8.4 — Auditar seguridad práctica.** Invitación imposible de saltar, permisos de columnas/RLS/RPC/Storage, usuarios desactivados, cierre concurrente, endpoint email protegido y ausencia de claves privadas o correos innecesarios en cliente/logs. Revisar configuración local y remota, no solo código.
- [ ] **F8.5 — Separar producción y validar despliegue Vercel.** Crear un proyecto Supabase de producción distinto antes de incorporar datos reales y aplicar solo migraciones revisadas, sin seed de pruebas. Preview/desarrollo apuntan a Supabase de desarrollo; Vercel Production a producción, con Auth/Storage/redirects propios. Mantener la guardia de tests apuntando a desarrollo. Verificar `env.js`, rutas profundas, callbacks y `/api/` fuera del fallback SPA; probar Preview antes de Production y revisar budgets.
- [ ] **F8.6 — Documentar operación y recuperación.** README con instalación, migraciones, primer admin, dominios/redirects, Storage y Resend. Procedimiento sencillo de respaldo/exportación y corrección de datos acorde al plan Supabase; confirmar las capacidades reales del plan Free, sin prometer backups no disponibles.
- [ ] **F8.7 — Hacer una prueba con amigos.** Jornada de prueba sin datos de producción, verificar que entienden envío definitivo, horarios manuales y puntuación. Resolver incidencias críticas antes de abrir la temporada real.

### Criterios de aceptación

- Flujos principales funcionan de extremo a extremo con usuarios reales de prueba y roles distintos.
- Build, pruebas frontend y pruebas de reglas/permisos pasan; no hay blockers funcionales o de seguridad abiertos.
- Se puede desplegar y operar siguiendo el README, sin pasos secretos ni modificaciones manuales no documentadas.
- El grupo puede usar la app desde móvil y el admin mantenerla cómodamente desde PC.

## Definición común de tarea terminada

Una tarea implementada se marca `[x]` solo cuando:

1. Cumple los requisitos y no contradice las reglas de negocio.
2. Sus permisos e invariantes se aplican en servidor cuando corresponde.
3. Tiene errores/carga/vacío resueltos y una UI responsive si incluye pantalla.
4. Sus casos relevantes están probados; build y pruebas relacionados pasan.
5. Migraciones, tipos y documentación afectados están sincronizados.

## Próxima acción recomendada

Continuar con **F1.6–F1.8: registro seguro, primer admin y autorización/RLS**, priorizando el orden que garantice que ningún flujo funcione sin políticas de backend. F1.3–F1.5 están cerradas y probadas en Supabase remoto de desarrollo; Docker sigue siendo opcional. La asignación del virtual al publicar una jornada se implementa en F3 y sus puntos/estadísticas en F5; proteger la lectura de `player_*_replaced_id` forma parte de F1.8. No desplegar el endpoint de correo sin protegerlo ni dar por finalizada la fase 1 por tener únicamente las tablas diseñadas.
