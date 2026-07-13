import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/boot_sequence_screen.dart';
import 'services/startup_service.dart';
import 'theme/vexon_colors.dart';
import 'widgets/custom_cursor.dart';
import 'widgets/kiosk_exit_guard.dart';
import 'widgets/windowed_title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registra VEXON per l'avvio automatico con Windows (vedi
  // services/startup_service.dart per i dettagli — funziona correttamente
  // solo sulla build di rilascio, non in `flutter run` debug).
  await StartupService.initialize();
  await StartupService.enable();

  // NOTA: i dati hardware (CPU/RAM) sono letti nativamente da Flutter via
  // FFI — vedi lib/services/native_hardware_reader.dart — senza bisogno di
  // avviare nessun servizio esterno. Il companion service .NET
  // (companion_service/) resta disponibile come opzione se in futuro
  // servono anche temperature e uso GPU reali, ma va avviato/installato a
  // parte: vedi companion_service/README.md.

  // Setup finestra kiosk: fullscreen, senza bordi, sempre in primo piano.
  // window_manager gestisce questo in modo cross-platform (Windows/Linux/macOS);
  // per il "vero" nascondere della taskbar e blocco Alt-Tab/tasto Windows
  // serve codice nativo aggiuntivo lato Windows (platform channel) — vedi
  // windows/runner/win32_window.cpp per l'implementazione da aggiungere.
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    fullScreen: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.black,
    minimumSize: Size(1024, 700), // dimensione minima quando si esce dal kiosk
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const VexonApp());
}

class VexonApp extends StatelessWidget {
  const VexonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VEXON',
      debugShowCheckedModeBanner: false,
      theme: VexonColors.darkTheme,
      home: const BootSequenceScreen(),
      builder: (context, child) {
        return CustomCursor(
          child: Column(
            children: [
              const WindowedTitleBar(),
              Expanded(
                child: KioskExitGuard(child: child ?? const SizedBox.shrink()),
              ),
            ],
          ),
        );
      },
    );
  }
}
