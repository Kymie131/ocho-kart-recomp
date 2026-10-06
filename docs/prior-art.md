# Prior art: todos los ports estáticos de Xbox 360 y qué le sirve a Ocho Kart

Investigación del 2026-10-06. Se clonaron y revisaron 58 repositorios públicos (3 más ya no son públicos) y se comparó contra el SDK fijado en `external/rexglue-sdk` (`c94f5eb`, Release v0.10.0) y contra Xenia Canary (`7ba916c`, 2026-10-06).

Lo que sigue sin medir en el juego está indicado como tal en `docs/STATE.md`.

---

## 1. Hallazgos y qué se hizo con cada uno (actualizado 2026-10-06, segunda sesión)

| # | Hallazgo | Estado tras verificar contra el dump |
|---|---|---|
| 1.1 | `KeInsertQueueDpc` nunca ejecuta el DPC en ReXGlue v0.10.0 (Canary sí; CrownPark lo arregló) | **Arreglado** (`patches/rexglue-sdk-dpc-dispatch.patch`). Pero el único DPC del título es de la librería **D3D** (rutina `0x82B63818`, despierta a un worker que si no espera 30 ms): mejora de latencia GPU, **no** es el bloqueo del audio. Rutina añadida al manifiesto. |
| 1.2 | `cache:` sin montar en ReXGlue; Xenia lo monta por defecto | **Arreglado** (`patches/rexglue-sdk-cache-mount.patch`). El XEX trae el código de caché de utilidad/DVD (`cache:\$cache$\dir`, `DvdCache`, `\Device\Harddisk0\Cache%u`); sin montaje ese `cache:` acababa en el NullDevice. Falta medir si afecta al audio. |
| 1.3 | `setjmp`/`longjmp` sin configurar | **Arreglado**: `longjmp 0x830BDC90`, `setjmp 0x830BDFB0` (7 y 18 call sites). |
| 1.4 | Bink no necesita decoder en el runtime | **Confirmado**: el XEX tiene secciones `BINK`, `BINKCONS`, `BINKDATA`, `BINKBSS`, `RADCODE`. |
| 1.5 | Los paquetes son LZX, no LZO | **Confirmado y resuelto**: `tools/catalog/ue3lzx.c` + `ue3_catalog.py` decodifican nombres/imports/exports. Reveló que el audio es **FMOD Ex + FMOD Event/Music** y que la música del menú es un cue FMOD disparado por Kismet en `TitleMap.xxx`. |
| 1.6 | Tirones por creación de PSO | **Corregido el diagnóstico**: el override D3D12 ya guarda las descripciones de pipelines (`shaders/shareable/*.d3d12.xpso`) y las precrea al arrancar; el `InitializeShaderStorage` vacío era la clase base. Los tirones son de primera ejecución. Una `ID3D12PipelineLibrary` como la de Gears J (`gowj_pso_library.cpp`) acortaría el arranque, pero no se escribió sin poder compilar/probar D3D12. |

### 1.7 Otros arreglos del fork CrownPark que conviene revisar o portar

| Arreglo | Por qué importa aquí |
|---|---|
| Eventos auto-reset que despiertan en orden FIFO | Un despertar arbitrario "se comía" la señal (cuelgue de SoulCalibur IV). Sirve para cualquier hilo de audio o streaming que espere eventos. |
| `WaitMultiple` bloqueante (antes hacía polling de 1 ms) | Rendimiento y latencia de los hilos de audio. |
| Restauraciones XMA de Canary (`output_buffer_valid`, protecciones del bucle de decodificación) | Coincide con las divergencias que `STATE.md` ya detectó en `XmaContext::Work()`. |
| `unregistered_function_nonfatal` y reescritura de GapFill | Sustituyen el ciclo manual de `peel.ps1` por recolección en lote de las funciones que faltan. |
| Guardián de esperas del invitado (`guest_wait_report_seconds`) | Convierte "el audio nunca arranca" en "este hilo espera este objeto desde esta dirección". Es justo la herramienta que falta para el punto 1 de "Next". |
| `--guest_watch=<addr>:<len>` | Protege páginas para saber quién escribe en la lista de voces `0x83C12330`. |
| `KeInsertQueueDpc` real | Ver 1.1. |
| Partición `cache:` escribible | Ver 1.2. |
| FP exceptions enmascaradas en todo hilo con código invitado | Evita SIGFPE espurios. |
| Advertencia `audio_native_xma` | Mezclar XMA nativo sin el estado por voz de **FMOD** produce estática. Confirma que el reproductor de música del host es el camino correcto como respaldo, y que no conviene intentar el "XMA nativo". |

### 1.8 La carrera de `InputSystem` ya está resuelta en otros forks

CrownPark serializó las tablas de dispositivos con el mismo mutex recursivo, y Gears J tiene `gowj_xam_input_guard`. Sirve como validación del parche de Ocho Kart y como argumento para upstream #475.

---

## 2. Inconsistencias en la documentación de Ocho Kart

Corregidas en `docs/STATE.md` (tabla "Corrections"); el registro antiguo queda en
`docs/history/STATE-log-2026-10.md`.

---

## 3. Catálogo completo de ports (estado al 2026-10-06)

Columna "UE3": juegos con Unreal Engine 3, los más parecidos a Ocho Kart.

### 3.1 ReXGlue SDK

| Juego | Repo | UE3 | Notas |
|---|---|---|---|
| Gears of War: Judgment | OverkillLabs3/gears-judgement-recomp | **sí** | v0.1.0 (2026-10-03). Bink del invitado, PSO library, KB/M, FSR/SMAA. El repo OverkillLabs2 ya no es público. |
| Silent Hill: Downpour | LittleBitUA/DownpourRecomp | **sí** | v1.1.8. Fuente del audio que Ocho Kart ya portó. 9 arreglos de upstream v0.10 portados a mano. |
| Lollipop Chainsaw (Re-Cherry) | MaxDeadBear/Re-Cherry | **sí** | Configura `setjmp`/`longjmp`. |
| Lost Odyssey | freefrank/LostOdysseyRecomp | **sí** | v0.8.39; Win/Linux/macOS/Android; shader pack precompilado. |
| Skate 3 | mchughalex/skate3recomp | no | 4K, ultrawide. |
| Naughty Bear Gold | MaxDeadBear/NaughtyBear_ReStuff | no | v1.5.1 |
| Banjo-Kazooie: Nuts & Bolts (reNut) | masterspike52/reNut | no | Launcher Goopie |
| Viva Piñata: TiP | SolarCookies/TiP-Recomp | no | v1.13.0 |
| GoldenEye 007 (XBLA) | SunJaycy/GoldenEye-Recomp | no | |
| Blue Dragon (re:Blue) | zolaware/reblue | no | v1.2.1 |
| Ninja Gaiden II (Ninja's Dawn) | TheSaltTrader/Ninja-s-Dawn… | no | Traductor GPU nativo propio |
| Ace Combat 6 | sal063/AC6_recomp | no | Ejecuta DPCs |
| Crackdown | SkiddyToast/Crackdown | no | |
| Crackdown 2 | matty45/Crackdown2-Recomp | no | Llega a in-game |
| Dante's Inferno | florinp93/hells-gate-recomp | no | Citado en los créditos de Ocho Kart |
| Castlevania SotN (XBLA) | birabittoh/NocturneRecomp | no | |
| Kameo: RePowered | birabittoh/KameoRePowered | no | Hooks de audio y Bink |
| Fable II | himdo/Fable-2-Recomp | no | Jugable de principio a fin |
| Fable II | Fable2Recomp/Fable2Recomp | no | |
| Project Gotham Racing 4 | beatrixzy/PGR4-Recomp | no | |
| DoDonPachi SaiDaiOuJou | eandis/SDOJ-Recomp | no | |
| Deadly Premonition | LittleBitUA/DPRecomp | no | D3D12 experimental |
| Daytona USA (XBLA) | Subarasheese/daytona-xbla-recomp | no | |
| Condemned 2 | psxrestore/Condemned2Recomp | no | |
| DBZ Budokai HD / Raging Blast 2 | WistfulHopes/DBZ1, WistfulHopes/RB2 | no | |
| Halo 3 (build de marzo 2007) | twist84/halo3_cache_release_recomp | no | Técnico, no jugable |
| LEGO Dimensions | NeverCookFirst/DimensionsRecomp | no | Beta jugable |
| The Simpsons Game | YesterMester/TheSimpsonsGameRecomp | no | Híbrido Xenon/ReXGlue |
| Cars | ant0-blase/Cars-X360-ReXGlue | no | |
| NHL Legacy | puckhead73/nhl-legacy-recomp | no | Completo, con mods |
| FIFA Street (2012) | samuelitodavila/fifa-street-pc | ? | Ya no es público |
| ~25 títulos (Ridge Racer Unbounded, Split/Second, PGR3/4, Burnout Revenge, Hydro Thunder, Shift 2, Midnight Club LA, SoulCalibur II HD/IV, Geometry Wars 1/2/3, Banjo-Kazooie/Tooie XBLA, Rez HD, After Burner Climax, Jetpac, Choplifter HD, Sonic 4 Ep1, Sega Rally, Alien Breed, Outrun Online, Space Giraffe, Bubble Bobble Neo…) | CrownParkComputing/Xbox360-Native-Ports (fork `rexglue-vmx`) | no | **El fork más documentado**: ver `docs/REXGLUE_FORK_CHANGES.md` |
| Simpsons Arcade, Vigilante 8, Guitar Hero II, Crazy Taxi, Comix Zone, Virtual On, Saints Row | sp00nznet/* (+ toolkit 360tools) | no | Varios jugables |
| WWE (Yuke's) | HollywoodAkeem/rexglue-sdk-yukes | no | Fork del SDK |

### 3.2 XenonRecomp / XenosRecomp (hedge-dev)

| Juego | Repo | UE3 |
|---|---|---|
| Sonic Unleashed | hedge-dev/UnleashedRecomp | no |
| Sonic '06 | sonicnext-dev/MarathonRecomp | no |
| GoldenEye 007 Remastered (XBLA) | Fable2Recomp/beanRecomp | no |
| Skate 2 (archivado) | Skate-2-Team/sk82-recomp | no |
| Test Drive Unlimited | testdriveupgrade/TDURecomp | no |
| Sonic Free Riders | YuutaTsubasa/Free-Riders-Recompiled | no |
| Dead Rising 2: Case Zero / Case West | wivi514/* | no |
| The Darkness | portingpete/The-Darkness-Recomp | no |
| Lost Odyssey (intento temprano) | lawlietl4/LostOdysseyRecomp | sí |

### 3.3 Otros enfoques

| Proyecto | Qué es |
|---|---|
| SomeoneIsWorking/gears1 (GearsUE3) | Gears of War 1 (UE3) sobre el dynarec de Xenia con overrides nativos; **no** es recompilación estática. Buena documentación UE3 (`docs/gearsue3-engine.md`, issues de audio). |
| nimauria/Xenon-Recomp | Runtime modular x86-64/ARM64 |
| shipa-2/rexglue-xerenge | Fork del SDK |
| sp00nznet/xboxrecomp | Xbox **original** (x86), no 360 |
| Goopie | Launcher común para ports ReXGlue |
| abduznik/awesome-x360-recomps | Lista curada (punto de partida) |

---

## 4. Plan

Ver "Next" en `docs/STATE.md`.
