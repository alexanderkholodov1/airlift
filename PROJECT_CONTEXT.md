# Proyecto: airlift (Godot 4.x)

## Resumen rapido
Juego 2D en Godot 4.6 (Forward Plus). Se centra en un personaje (Logan) que avanza por niveles, con dialogos y un tutorial guiado. Hay escenas de mundo (forest, limbo, cavern, boss) y un flujo de menu principal. El estilo general es 2D con sprites y musica ambiental. La atmosfera es oscura/misteriosa; el tutorial introduce la idea de estar en un "umbral" y ser guiado por una entidad. Hay enfasis en narrativa y aprendizaje de controles.

## Estructura del proyecto
- scenes/
  - Tutorial.tscn: escena de tutorial con dialogos y acciones guiadas.
  - Main_Scene.tscn: menu principal.
  - forest.tscn, limbo.tscn, cavern.tscn, boss.tscn: niveles principales.
  - Logan.tscn: personaje jugador.
  - enemy.tscn, enemy_tree.tscn, etc.: enemigos.
  - ui/ (varias escenas UI): pause_menu.tscn, settings_menu.tscn, menu_credits.tscn, pause_button.tscn, death_screen.tscn.
- scripts/
  - logan.gd: movimiento, trepar, agarrar y lanzar objetos.
  - dialogue.gd: control del tutorial, dialogos y acciones guiadas.
  - game_flow.gd: autoload para pausa, restart, menu, etc.
  - pause_menu.gd, settings_menu.gd, menu_credits.gd, pause_button.gd: UI.
  - scene_transition.gd: transiciones entre escenas (autoload existente).
- assets/
  - sprites/, sounds/, music/, fonts/

## Motor y configuracion
- Godot 4.6, renderer Forward Plus.
- main_scene: Main_Scene.tscn.
- Input map: action "skip" existe (configurada en project.godot).
- Escala de ventana: canvas_items + expand (configurado anteriormente).

## UI y flujo global
- Autoloads:
  - SceneTransition (existente).
  - GameFlow (agregado) para pausa, restart de nivel actual, menu, salir, etc.
- Pause menu:
  - Se abre con Esc o con boton flotante en gameplay.
  - Opciones: volver, restart, menu, salir.
- Settings:
  - Toggle fullscreen (limitado por ventana embebida del editor).
  - Guarda en user://display_settings.cfg.
- Credits:
  - Pantalla dedicada con texto editable.

## Tutorial y dialogo
- Tutorial.tscn usa scripts/dialogue.gd para dialogos secuenciales.
- El flujo actual incorpora pasos que esperan acciones del jugador:
  - Caminar con click izquierdo.
  - Tomar objeto con click derecho.
  - Soltar/lanzar con click derecho.
- El speaker "..." se oculta en el dialogo (solo texto).
- Se muestra un prompt UI con icono y texto durante acciones (ActionPrompt).
- El avance con boton derecho se bloquea mientras la accion no se complete.
- El texto del dialogo tiene font size aumentado.

## Personaje (Logan)
- Movimiento con click izquierdo (mantener para caminar hacia el mouse).
- Trepar lianas con click derecho sostenido.
- Agarrar/soltar objetos con click derecho (si no trepa).
- Speed exportable y ajustable por escena (en tutorial esta reducido).

## Atmosfera y genero
- Genero: aventura 2D narrativa con accion ligera.
- Atmosfera: oscura, misteriosa, tono de umbral/limbo.
- Tema narrativo: redencion, consecuencias, viaje guiado.
- Musica ambiental: tutorial_bloomsaw, alien_limbo, etc.
- Visual: sprites retro y fondos con capas.

## Puntos sensibles / decisiones recientes
- Fullscreen no funciona en ventana embebida del editor; necesita ventana separada para fullscreen real.
- Se creo un boton flotante de pausa para jugar sin teclado.
- El menu principal requiere que el script jugar.gd este en el Control root, no en el boton.

## Archivos clave
- scripts/dialogue.gd
- scripts/logan.gd
- scripts/game_flow.gd
- scenes/Tutorial.tscn
- scenes/Main_Scene.tscn
- scenes/ui/pause_menu.tscn, settings_menu.tscn, menu_credits.tscn, pause_button.tscn

## Sugerencias de continuidad
- Verificar prompts de tutorial con iconos reales si se desea.
- Ajustar tiempos y texto del tutorial segun feedback.
- Validar transiciones y restart en cada nivel.
- Revisar fullscreen en build final y no en embebido.
