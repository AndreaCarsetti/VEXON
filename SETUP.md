# VEXON — Setup progetto

## Come partire

Questo è lo scaffolding, non un progetto Flutter completo generato da
`flutter create` — mancano le cartelle native (`windows/`, `android/`).
Per crearle:

```bash
# In una cartella vuota
flutter create --platforms=windows,android vexon_temp

# Poi copia dentro vexon_temp/ i contenuti di questo pacchetto:
#   - lib/         (sovrascrivi lib/main.dart esistente)
#   - assets/
#   - pubspec.yaml (sovrascrivi, o unisci le dipendenze)

cd vexon_temp
flutter pub get

# Genera l'icona app (funziona su Windows)
dart run flutter_launcher_icons

# NOTA: flutter_native_splash NON supporta Windows (solo Android/iOS/Web).
# Lo splash per Windows è già gestito in Flutter stesso, vedi
# lib/screens/splash_screen.dart — non serve alcun comando aggiuntivo,
# funziona appena lanci l'app. Il comando sotto serve solo se in futuro
# aggiungi anche una build Android:
# dart run flutter_native_splash:create

# Avvia in modalità sviluppo
flutter run -d windows
```

## Cosa c'è già

- **`lib/theme/vexon_colors.dart`** — palette VEXON completa + ThemeData
- **`lib/models/game.dart`** — modello dati gioco
- **`lib/services/game_scanner_service.dart`** — scanner libreria **Steam
  ed Epic Games** (GOG resta uno stub, stessa interfaccia). Epic legge i
  file `.item` (JSON) in
  `C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests` — percorso fisso,
  a differenza di Steam non è configurabile dall'utente. Un manifest
  corrotto/malformato viene saltato senza bloccare la scansione degli
  altri.
- **`lib/widgets/staggered_fade_in.dart`** — anima l'ingresso di ogni card
  della griglia con fade + leggero slide dal basso, con un ritardo
  crescente in base alla posizione (effetto "a cascata" invece che tutte le
  card che compaiono di scatto insieme). Il ritardo massimo è limitato,
  così anche con librerie enormi l'ultima card non aspetta secondi interi.
- **`lib/widgets/vexon_loading_indicator.dart`** — il simbolo VEXON che
  pulsa (scala + opacità) al posto del generico `CircularProgressIndicator`
  durante la scansione della libreria.
- **`lib/widgets/game_card.dart`** — ora ha: leggero ingrandimento al
  passaggio del mouse (oltre al bordo rosso già presente), un piccolo
  "schiacciamento" al click per dare feedback tattile, e un badge in alto a
  sinistra con l'icona della piattaforma (Steam/Epic/GOG) — utile ora che
  la libreria aggrega più fonti insieme.
- **`lib/screens/boot_sequence_screen.dart`** — sequenza "glitch" mostrata
  PRIMA dello splash (è la vera schermata iniziale in `main.dart`, non
  `SplashScreen`): sfarfallio rosso irregolare di fondo, barre di disturbo
  orizzontali tipo segnale corrotto, e il logo che appare a scatti offset
  tra i glitch — poi un taglio secco al nero (non una dissolvenza morbida,
  di proposito) prima di passare allo splash col fade-in pulito del logo.
  Gli eventi (barre, lampi del logo) sono precalcolati una volta in
  `initState` con un seed fisso (`Random(7)`), non generati ad ogni frame —
  così il pattern resta identico ad ogni avvio invece di cambiare a
  caso ogni volta. Durata totale 2.4s. **Stesso fix del timing già
  applicato allo splash**: l'animazione parte solo al primo frame
  effettivamente disegnato (`addPostFrameCallback`).
- **`lib/screens/splash_screen.dart`** — la transizione verso la home ora
  usa un fade pulito (`PageRouteBuilder` custom) invece dello slide-up di
  default di `MaterialPageRoute`, per un passaggio più impercettibile dato
  che lo splash è già invisibile quando ci si arriva.
- **`lib/widgets/particle_background.dart`** — sfondo animato con
  particelle rosse che fluttuano lentamente verso l'alto, dietro alla
  griglia giochi. Usa un `Ticker` + `ValueNotifier` invece di `setState`
  per ridisegnare SOLO le particelle ad ogni frame, non l'intera schermata
  — importante per le prestazioni a 60fps.
- **`lib/widgets/sparkline.dart`** + **`lib/widgets/hardware_hud.dart`**
  (riscritto) — l'HUD ora mostra un mini-grafico storico (tipo Task
  Manager) per CPU/GPU/RAM invece dei soli numeri statici. Lo storico
  (ultimi 40 campioni,~40 secondi) è mantenuto in `home_screen.dart`.
- **`lib/widgets/top_bar.dart`** — il pulsante GAME MODE, quando attivo, ha
  ora un bagliore che "respira" (pulsa dolcemente tra due intensità)
  invece di un alone statico — comunica meglio che il Boost è attivo e
  "vivo".
- **`lib/widgets/custom_cursor.dart`** — sostituisce il cursore di sistema
  con uno disegnato su misura: un mirino/crosshair stile FPS (quattro
  tratti brevi con spazio vuoto al centro + anellino sottile), bagliore
  rosso, e una breve scia di scintille ambra che segue il movimento del
  mouse — usa lo stesso linguaggio visivo di `particle_background.dart`.
  Avvolge l'intera app dal livello più esterno in `main.dart`, così vale su
  ogni schermata. Nota tecnica: l'overlay del cursore usa `IgnorePointer`,
  quindi non blocca mai i click reali sui widget sottostanti — disegna
  soltanto, non intercetta l'input.
- **`lib/services/hardware_monitor_service.dart`** — interfaccia hardware
  con **tre implementazioni**: `.mock()` (dati finti, per sviluppo rapido),
  `.native()` (**quella usata di default** in `home_screen.dart` — CPU e
  RAM reali via FFI, nessun servizio esterno, GPU/temperature mostrate come
  "N/D") e `.companion()` (dati completi incluse temperature, ma richiede
  di compilare/avviare il servizio .NET separato con privilegi admin).
- **`lib/services/native_hardware_reader.dart`** — legge CPU (via
  `GetSystemTimes`, confrontando il tempo idle tra due letture) e RAM (via
  `GlobalMemoryStatusEx`) direttamente con le API Windows tramite FFI
  (`package:win32`). Nessuna installazione aggiuntiva, nessun permesso di
  amministratore. **Limite**: GPU e temperature non sono leggibili così,
  serve accesso a driver di sistema più profondo — restano `null` (mostrati
  come "N/D" nell'HUD) a meno di passare a `.companion()`.
- **`lib/services/hardware_companion_launcher.dart`** — avvia
  `vexon_hardware_service.exe` come processo separato, **solo se scegli di
  usare `.companion()`** invece di `.native()`. Non richiamato di default
  in `main.dart`.
- **`companion_service/`** — progetto .NET **opzionale**, da usare solo se
  in futuro vuoi davvero temperature e uso GPU reali (richiede privilegi di
  amministratore — vedi `companion_service/README.md`). Non necessario per
  il funzionamento base dell'app.
- **`lib/services/kiosk_service.dart`** — entra/esce dalla modalità
  fullscreen/always-on-top via `window_manager`, e sincronizza
  `WindowState.isKiosk`.
- **`lib/services/game_boost_service.dart`** — il vero "Game Mode",
  collegato al pulsante già presente nella TopBar. Fa esattamente due cose,
  entrambe reversibili: cambia il piano di alimentazione su "Prestazioni
  elevate" (ripristinando quello precedente alla disattivazione) e abbassa
  la priorità — **mai chiude né sospende** — di una whitelist ristretta e
  esplicita di app di sincronizzazione note (OneDrive, Dropbox, Google
  Drive, Adobe Desktop Service). Non tocca processi di sistema, non tocca
  app di comunicazione (Discord, browser...), non silenzia le notifiche di
  Windows (rimandato, richiederebbe API non ufficialmente documentate).
- **`lib/widgets/game_boost_transition.dart`** — overlay animato (~1.6s)
  mostrato ad ogni attivazione/disattivazione del Game Boost: sfondo che si
  scurisce, tre anelli rossi che si espandono dal centro con partenza
  scaglionata, icona e testo "GAME BOOST ATTIVO/DISATTIVATO" con un
  leggero rimbalzo elastico, poi tutto sfuma via da solo. Non blocca
  l'interazione con l'app sotto (`IgnorePointer`).
- **`lib/services/window_state.dart`** — un semplice `ValueNotifier<bool>`
  globale che dice se l'app è in modalità kiosk o finestra normale. Usato
  da `WindowedTitleBar` per capirsi quando mostrarsi.
- **`lib/services/startup_service.dart`** — registra VEXON per l'avvio
  automatico con Windows (via `launch_at_startup`, stesso meccanismo di
  Steam/Discord: entry nel registro `HKCU\...\Run`, no permessi admin).
  **Va testato sulla build di rilascio**, non con `flutter run` — in debug
  `Platform.resolvedExecutable` punta al processo Dart, non al vero .exe.
- **`lib/widgets/kiosk_exit_guard.dart`** — ascolta ESC a livello globale;
  tenuto premuto 2 secondi mostra un indicatore di progresso, esce dalla
  modalità kiosk (finestra normale, ridimensionabile) e aggiorna
  `WindowState.isKiosk`. Rilascio anticipato annulla l'operazione.
- **`lib/widgets/windowed_title_bar.dart`** — barra sottile (32px) in alto,
  **visibile solo quando non si è in modalità kiosk**. È un'area
  trascinabile (`DragToMoveArea` di `window_manager`) per spostare la
  finestra — necessaria perché `titleBarStyle` è `hidden`, quindi Windows
  non offre più questo comportamento di serie — con tre pulsanti in alto a
  destra: riduci a icona, torna a schermo intero (rientra in kiosk),
  chiudi. Niente logo/testo qui: la TopBar dell'app sotto ce l'ha già,
  ripeterlo creava una sovrapposizione visiva. **Struttura in
  `main.dart`**: `Column([WindowedTitleBar, Expanded(KioskExitGuard(child))])`
  — la barra sta fuori dal `KioskExitGuard` e in cima alla `Column`, non
  annidata dentro un altro widget che poi finisce in uno `Stack`. È la
  struttura più semplice che garantisce vincoli di layout validi per
  l'`Expanded` interno.
- **`lib/screens/splash_screen.dart`** — logo con fade-in (900ms), resta
  visibile (2200ms), fade-out (700ms) prima di passare alla home. Durata
  totale ~3.8s, facilmente regolabile modificando le costanti in cima al
  file. **Nota tecnica**: l'animazione parte solo al primo frame
  effettivamente disegnato (`addPostFrameCallback`), non appena il widget
  viene costruito — su Windows la finestra nativa appare prima che Flutter
  disegni, quindi partire subito avrebbe "mangiato" parte del fade-in nel
  tempo morto tra creazione finestra e primo frame reale.
- **`lib/screens/home_screen.dart`** — shell principale: griglia giochi,
  ricerca, toggle Game Mode, HUD hardware in basso a destra
- **`lib/widgets/`** — componenti riutilizzabili (card gioco, top bar, HUD)
- **`lib/main.dart`** — bootstrap finestra fullscreen kiosk via
  `window_manager`
- **`installer/vexon_installer.iss`** — script Inno Setup per generare un
  installer `.exe` distribuibile (vedi sezione dedicata sotto).

## Se vedi ancora un lampo bianco prima dello splash

Con la correzione sopra il fade-in del logo dovrebbe essere completo e
visibile. Se però noti ancora un breve lampo bianco/vuoto della finestra
*prima* che compaia lo splash (un problema diverso, a livello di finestra
nativa più che di animazione), la soluzione definitiva è impedire a Windows
di mostrare la finestra finché Flutter non è pronto. Richiede una patch
nativa in `windows/runner/win32_window.cpp` (cambiare `WS_OVERLAPPEDWINDOW |
WS_VISIBLE` in solo `WS_OVERLAPPEDWINDOW`) e in `windows/runner/flutter_window.cpp`
(rimuovere la chiamata automatica a `this->Show()` nel callback del primo
frame, dato che la mostriamo noi esplicitamente da `main.dart`). Dettagli:
https://leanflutter.dev/documentation/window_manager/quick-start#hidden-at-launch

## Creare l'installer Windows (.exe)

```bash
# 1. Compila la build di rilascio
flutter build windows

# 2. Installa Inno Setup (gratuito): https://jrsoftware.org/isinfo.php

# 3. Apri installer/vexon_installer.iss con Inno Setup Compiler e premi
#    "Compile" — oppure da riga di comando:
iscc installer\vexon_installer.iss

# Il risultato è installer/output/VEXON_Setup.exe — un installer singolo
# che copia l'app in Program Files, crea le voci nel menu Start e
# (opzionale) un'icona sul desktop.
```

**Prima di compilare**, apri `vexon_installer.iss` e verifica che
`SourceDir` punti davvero alla cartella generata da `flutter build windows`
sul tuo PC — di solito `build\windows\x64\runner\Release`, ma il percorso
esatto può variare in base alla versione di Flutter.

**Nota importante su SmartScreen**: senza un certificato di code signing,
al primo avvio dell'installer Windows Defender SmartScreen mostrerà un
avviso "editore sconosciuto" — è normale per software non firmato, non è
un errore nello script. Se prevedi di vendere VEXON a clienti B2B (locali,
gaming lounge), un certificato di code signing (da ~70-300€/anno secondo
il provider) elimina l'avviso e trasmette più professionalità: vale la
pena valutarlo quando il prodotto sarà pronto per la vendita vera e
propria, non è urgente per i test iniziali.

## Prossimi passi consigliati (in ordine)

1. **Far girare l'app con dati mock** — verifica che layout/tema/griglia
   funzionino su un PC Windows reale con Steam installato, per validare lo
   scanner Steam con la tua libreria vera. Verifica anche che ESC tenuto
   premuto 2 secondi esca correttamente dal fullscreen, che la finestra
   risultante sia spostabile trascinando la barra in alto, e che i tre
   pulsanti (riduci/schermo intero/chiudi) funzionino.
2. **Verificare i dati hardware nativi** — con `.native()` già attivo di
   default, l'HUD dovrebbe mostrare CPU e RAM reali del tuo PC appena lanci
   l'app, senza dover avviare nulla di separato. GPU e temperature
   mostreranno "N/D" — è atteso, non un bug (vedi limite sopra). Se in
   futuro vuoi anche quei dati, il companion service (opzionale) è già
   pronto in `companion_service/`.
3. **Copertine giochi** — Steam CDN espone le cover tramite l'App ID
   (`https://cdn.akamai.steamstatic.com/steam/apps/{appid}/library_600x900.jpg`),
   utile per non dover fare scraping.
4. **Nascondere davvero la taskbar / bloccare Alt-Tab** — richiede codice
   nativo Win32 in `windows/runner/`, non incluso in questo scaffold
   (`KioskService` gestisce solo fullscreen/always-on-top via
   `window_manager`, che è cross-platform ma non tocca la shell di Windows).
5. **Istanza singola** — con l'avvio automatico attivo, se l'app viene
   anche aperta manualmente si rischiano due copie in esecuzione
   contemporaneamente. Il pacchetto `windows_single_instance` risolve
   questo: alla seconda apertura, riporta in primo piano quella già aperta
   invece di avviarne una nuova. Non ancora incluso in questo scaffold —
   da aggiungere prima di distribuire l'app a un locale.
6. **Ripristino Game Boost alla chiusura forzata** — se l'utente chiude
   VEXON (es. da Task Manager) mentre il Game Boost è attivo, il piano di
   alimentazione resta su "Prestazioni elevate" invece di tornare a quello
   precedente, perché `GameBoostService.disable()` non viene mai chiamato.
   Non è pericoloso (nessun dato a rischio), ma non è pulito. Da risolvere
   con un `WindowListener.onWindowClose` che chiama `disable()` prima di
   uscire — stesso meccanismo utile anche per il punto 7 sotto.
7. **Spegnimento pulito del companion service** (solo se in futuro passi a
   `.companion()` per temperature/GPU) — oggi
   `HardwareCompanionLauncher.stop()` è vuoto: se chiudi VEXON, il
   companion resta in esecuzione in background come processo orfano.

## Nota sulla libreria Steam multi-disco

Lo scanner attuale legge solo la libreria Steam di default. Se hai giochi
installati su altri dischi, Steam li elenca in
`steamapps/libraryfolders.vdf` — è il prossimo file da parsare per una
scansione completa.
