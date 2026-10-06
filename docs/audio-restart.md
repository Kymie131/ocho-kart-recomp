# Audio — reinicio limpio (2026-10-03)

Documento canónico de audio. Las secciones históricas contradictorias de `STATE.md`
quedan archivadas en `docs/audio-investigation-archive.md`. **No reabrir teorías viejas
sin evidencia nueva medible.**

## Hechos medidos (conservar)

### Runtime host (funciona)
- Endpoint SDL abre `2 ch / 48000 Hz` en los speakers Realtek.
- El título registra **2 clientes XAudio** (`XAudioRegisterRenderDriverClient` ×2).
- Ambos clientes suben frames al mismo buffer guest `0x83C12870`.
- `XAudioSubmitRenderDriverFrame` se llama; el worker de audio corre.

### Guest (silencioso en menú/carreras)
- El mixer del título entrega `peak=0` y luego basura (`FLT_MAX`) en ese buffer.
- La voz-manager `sub_82B893A0` (arma la lista de voces y llama a
  `sub_82B8B8C0` → `sub_82B8AC20` → `XMACreateContext`) **no corre en el menú**.
- El tick `sub_82B8B448` corre constante y barre el array de 320 slots vacío.
- XMP solo hace handshake de ownership; no hay playlist ni playback.
- Imports XMA del title: **solo** `XMACreateContext` / `XMAReleaseContext`.
  No importa `XMAEnableContext` / `XMADisableContext`.

### Path XMA del guest (lectura de código recompilado)
- `sub_82B8AC20` (`.89`): crea contexto, `MmMapIoSpace`, escribe Clear `0x6A0`.
- `sub_82B8B448` (`.301`): para cada contexto listo escribe Lock `0x690`.
- **Corrección (2026-10-03, tarde): SÍ existe un escritor de Kick `0x650`.**
  `sub_82B8B5B8` (`.92`) recorre la lista de voces y por cada contexto listo escribe
  Kick (`0x650`, físico `0x1FFA8650`). Se llama desde `sub_82B875B8` (método virtual).
  La afirmación anterior "nunca escribe Kick" era falsa: solo se habían mirado `.89`
  y `.301`.
- Por tanto el shim (Kick → `Enable()` + `Work()`) es correcto; el muro no es que
  falte Kick, es que en el menú **no se crea ningún contexto**, así que no hay a quién
  kickear.

### Assets de audio del dump
- 12 bancos `*.fsbcache` en `ChavoKartGame/CookedXbox360/` (magic `FSB5`).
- Paquete UE3 `FMODAudio.xxx` (solo referencias, 32 KB).
- Películas Bink en `Movies/*.BIK` (cinemáticas, no mixer de juego).
- ffmpeg del sistema: demuxer FSB **no implementa FSB5**; **sí** tiene decoders `xma1`/`xma2`.

## Instrumentación en el runtime (2026-10-03, tarde)

Vendored `external/rexglue-sdk/src/audio/xma_decoder.cpp` (parche:
`patches/rexglue-sdk-xma-trace-and-lock-decode.patch`; runtime reconstruido en
`out/win-amd64/RelWithDebInfo` y desplegado al build del juego):

- `xma_trace_writes` (default **false**): loguea cada write de contexto
  (Kick/Lock/Clear) y el registro de transacción `0x601` (deduplicado).
  Activar con `REX_XMA_TRACE_WRITES=true`.
- `xma_lock_decodes` (default **false**): experimental, además de Kick trata un
  Lock como enable+decode. **No lo enciendas todavía**: ver medición abajo.

## Medición boot→menú (2026-10-03, tarde)

`REX_XMA_TRACE_WRITES=true`, 130 s desde el arranque hasta el menú:
**35 283 writes, todos a `0x601` (`0x02`/`0x03`). Cero Kick, cero Lock, cero Clear.**
Confirma con dato duro lo que se deducía: en el menú no se crea ningún contexto,
el array de 320 slots está vacío y solo corre la transacción `0x601` del tick
`sub_82B8B448`. No hay nada que decodificar.

La medición decisiva que falta es **en carrera**: con `xma_trace_writes` activo,
entrar a una pista y ver si aparecen Kick/Lock/Clear. Eso decide si el shim ya
decodifica los efectos y aísla el problema a "el menú no arranca la música".

## Audio host-side: parser FSB5 + decode XMA → audible (2026-10-04, hecho)

Se ataca el deliverable "audio host-side audible" (fallback del plan): leer los
bancos del dump directamente y sonar en el PC, sin tocar el guest ni el runtime.

Herramienta nueva, C++17 sin dependencias (solo std):

- `tools/fsb5/fsb5.cpp` — parser FSB5 (versión 1; codec `0x0A` = XMA, y PCM8/16)
  y escritor de WAV.
  - XMA → WAV con chunk **`XMA2`** (XMA2WAVEFORMAT v4). FFmpeg lo demuxa con
    `wav_parse_xma2_tag` y decodifica con su decoder `xma2` nativo (el bitstream
    XMA son frames de 2048 bytes que el parser entrega tal cual).
  - PCM8/16 → WAV PCM directo.
  - Comandos: `list <bank...>`, `extract <bank> <idx> <out.wav>`,
    `extract-all <bank> <outdir>`.
- `tools/fsb5/build.ps1` — compila con clang/VS BuildTools a `tools/out/fsb5.exe`
  (gitignored).
- `tools/fsb5/play.ps1` — extrae + decodifica con `ffmpeg` y opcionalmente
  reproduce con `ffplay` (`-Play`), o guarda PCM (`-Out`). Disponible si
  FFmpeg está en PATH o se pasa `-FfmpegDir`.

Medido (2026-10-04):

- Los **15** bancos `*.fsbcache` son FSB5 v1 codec `0x0A` (XMA): **7034 subsounds**
  en total, **cero warnings** de parseo. Nombres legibles cuando existen
  (p. ej. `brasil_soccer_final_01`).
- `95D00942` (música, 2ch/48kHz) #0: decodifica 2.47 s, `mean -29.2 dB`,
  `max -10.5 dB`. #1: 44.54 s, `mean -23.0 dB`, `max -8.8 dB`. Señal real.
- `649B9BA1`: `extract-all` saca los 25 sin fallo y todos decodifican con señal
  (`mean ≈ -19 dB`).
- El mismo resultado se obtuvo primero con un prototipo Python en el temp; el
  parser C++ reproduce idéntico (`mean -29.2 dB` en #0).

Esto **cierra el fallback host-side**: la música y los efectos del dump son
decodificables y audibles en el host hoy, independientemente de que el mixer del
guest siga mudo.

Pendiente (opcional, integración en el runtime): enganchar un reproductor
host-side al runtime para oír música mientras se juega. Requiere elegir el
subsound según estado menú/carrera (o el sistema/gesto que el guest no levanta).
El parser ya está en C++ para reutilizarlo dentro del runtime.

## Player host-side en el runtime (2026-10-04, hecho)

Se integró un reproductor in-process en el overlay del juego
(`src/audio/host_music.h` + `ocho_kart_app.h`, en `src/launcher/` y en el
proyecto real):

- `ocho::audio::HostMusic` abre un `SDL_AudioStream` (48 kHz stereo s16) en el
  dispositivo por defecto y reproduce WAV pre-decodificados en bucle. El WAV se
  carga y se convierte a 48 kHz stereo (PCM16) con interpolación lineal
  —cualquier rate/canales del dump sirve.
- Selección de pista por **heurística de estado**: lee el array de punteros de
  voces XMA del guest en `0x83C12330` (320 entradas, stride 4; el mismo que barre
  `sub_82B8B448`). Vacío → `menu.wav`; con entradas → `race.wav`. Cada ~250 ms.
- Enganchado en `OnPostSetup` (arranca; obtiene el guest memory por
  `runtime()->memory()->TranslateVirtual`) y `OnShutdown` (para).
- Todo opt-in: cvar `host_music` (default **false**). Si el dispositivo o el WAV
  fallan, se desactiva solo y no toca el path del guest.

Cvars (categoría `Audio`): `host_music`, `host_music_dir`,
`host_music_menu` (def `menu.wav`), `host_music_race` (def `race.wav`),
`host_music_gain`, `host_music_state_addr` (`0x83C12330`),
`host_music_state_stride` (4), `host_music_state_count` (320),
`host_music_poll_ms` (250).

Uso: exportar las pistas al dump (o a `host_music_dir`):

```
powershell -File tools/fsb5/play.ps1 -Bank "<dump>\...\95D00942.fsbcache" -Index 0 -Out "<dump>\host_music\menu.wav"
powershell -File tools/fsb5/play.ps1 -Bank "<dump>\...\95D00942.fsbcache" -Index 1 -Out "<dump>\host_music\race.wav"
```

y lanzar con `--host_music true` (o `host_music=true` en la config).

Medido (2026-10-04, smoke boot→menú, 40 s, `--host_music true`):

- `host_music: started dir='...\host_music' menu='menu.wav' race='race.wav'`
- `host_music: playing 'menu.wav' (menu)` a los ~0.25 s: la heurística leyó el
  array de voces vacío del menú correctamente.
- Proceso vivo 40 s, sin FATAL ni `Call to invalid`. Nota: en el primer intento
  SDL audio no estaba inicializado en `OnPostSetup`; se corrige con
  `SDL_InitSubSystem(SDL_INIT_AUDIO)`.
- No verificable en este entorno: salida audible real y el cambio a `race.wav`
  en carrera (requiere entrar a una). La lógica de estado sí se ejercitó.

## Diagnóstico del guest: el título nunca carga los bancos (2026-10-04, cerrado)

Con el debugger simbolizado (LLDB; ver `tools/debug-audio.ps1`) saqué la
**cadena real del guest** en la apertura de `FMODAudio.xxx`:

```
NtCreateFile_entry <- sub_830D0FA0 <- sub_829E4F40 <- sub_822EB0F0
                   <- sub_822EB888 <- sub_8235CB60 <- sub_830E9C98 (hilo)
```

Evidencia medida:
- ReXGlue abre `FMODAudio.xxx` pero **nunca ningún `.fsbcache`**; Xenia abre 7
  bancos (loader `<hash>.xxx`→`<hash>.fsbcache`). En ReXGlue **ningún asset de
  sonido** pasa por el cargador de paquetes UE3 → el sistema de audio del título
  **nunca activa voces**.
- El motor/hilos SÍ funcionan: el mixer (`sub_82BB1188`) corre y sube frames; los
  workers `sub_82BAD4B0`/`sub_82ED1B98` se crean y ejecutan con **los mismos
  `start`/`ctx` que Xenia**.
- No es shim: ningún `XAudio*` stub se usa (solo `XamVoiceSetMicArrayIdleUsers`).
  No es el perfil ni un mute. No es VFS (no hay opens fallidos de bancos) ni el
  decoder (ya se portó el de Downpour, sin efecto).
- Conclusión: es la **activación de audio del título** (SoundCue del menú/carrera
  no se disparan). Arreglarlo es RE del sistema de audio UE3 del juego, no un
  parche puntual. Xenia lo activa; ReXGlue no.

Herramienta dejada para esa sesión: `tools/debug-audio.ps1` (LLDB + PDBs del exe
y del runtime; stacks del guest simbolizados; junction sin espacios
`C:\Users\israe\ocho_dump`). Breakpoints en `sub_822EB0F0`/`sub_822EB888` (cargador
UE3) o `sub_830D0FA0` (apertura de archivo).

## Host-side player: colocado (2026-10-04, hecho)

`ocho::audio::HostMusic` (overlay del juego) queda bien colocado:
- Pista de **menú** por defecto; cambia a **carrera** cuando el array de voces
  XMA del guest (`0x83C12330`) tiene entradas.
- **Se calla durante la intro**: cvar `host_music_start_delay_ms` (default
  15000) retrasa el arranque para no encimarse con los logos/cinemática.
- Cvars: `host_music` (off), `host_music_dir`, `host_music_menu`, `host_music_race`,
  `host_music_gain`, `host_music_state_addr/stride/count`, `host_music_poll_ms`,
  `host_music_start_delay_ms`.
- Uso: exportar con `tools/fsb5/play.ps1 -Bank ... -Out "<dump>\host_music\menu.wav"`
  y lanzar con `--host_music true`.

Medido: arranca tras el delay y reproduce `menu.wav`; el juego sigue vivo (25 s).
Nota: hay un cierre intermitente de launcher (issue abierto) ajeno al player.

## Extracción automática y toggle en el launcher (2026-10-06, hecho)

Para que la música no dependa de exportar a mano:

- `tools/host-music.ps1` indexa los bancos `*.fsbcache` del dump, elige la
  pista de menú (`Main_full_02`) y de carrera (`Acapulco_final_02`) por nombre y
  escribe `menu.wav`/`race.wav` en `<dump>/host_music` (usa `fsb5.exe` + FFmpeg;
  `-All` vuelca todas las pistas). Verificado: `menu.wav` 32.7 MB (170 s),
  válido con señal.
- El launcher (`ocho_kart_app.h`) añade el check **Background music (host)**,
  activado por defecto si ya existen `menu.wav`/`race.wav`; al aceptar fija
  `host_music`. También expone `fullscreen`, `vsync` y `resolution_scale`.
- `tools/install-launcher.ps1` despliega además `src/audio/host_music.h`.

Medido: boot con `--host_music true` registra `host_music: playing 'menu.wav'`
y el proceso sigue vivo; salida audible no verificable aquí.

## Plan (híbrido)

| Paso | Qué | Estado |
|---|---|---|
| 1 | Docs limpios (este archivo) | hecho |
| 2 | Shim: Lock `0x690` también hace Enable+Work (cvar `xma_lock_decodes`) | implementado, **default false** (diverge de Xenia; medir antes) |
| 3 | Diagnóstico: log de writes XMA `(r,value)` boot→menú | hecho: solo `0x601`; falta boot→carrera |
| 4a | Host-side: parser FSB5 + decode XMA→WAV + reproducción | **hecho** (`tools/fsb5/`) |
| 4b | Host-side: player en el runtime colocado (menú/carrera, callado en intro) | **hecho** (`host_music`) |
| 5 | Audio del guest: activación UE3 del título no se dispara | **localizado**, necesita RE del sistema de audio UE3 |

## Reglas de esta sesión
- Una hipótesis a la vez; medir antes de “confirmar”.
- Instrumentación temporal se revierte o se deja con cvar off por defecto.
- No commit de assets del dump.
- Si el path guest no cae en N iteraciones, el deliverable es audio host-side audible.
