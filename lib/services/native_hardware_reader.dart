import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'scanners/win32_registry_utils.dart';

/// Legge CPU e RAM direttamente dalle API native di Windows, tramite FFI —
/// nessun processo esterno, nessun permesso di amministratore richiesto.
///
/// USA:
/// - `GetSystemTimes` (kernel32) per il carico CPU complessivo: confronta il
///   tempo "idle" con il tempo totale trascorso tra due letture consecutive.
/// - `GlobalMemoryStatusEx` (kernel32) per la RAM: Windows la calcola già
///   internamente, nessun calcolo manuale necessario.
///
/// LIMITE NOTO: GPU e temperature CPU/GPU non sono leggibili in questo modo
/// — richiedono driver di sistema a basso livello (vedi
/// `companion_service/README.md` se in futuro servono davvero).
class NativeHardwareReader {
  int? _lastIdle;
  int? _lastKernel;
  int? _lastUser;

  /// Ritorna la percentuale di utilizzo CPU dall'ultima chiamata, oppure
  /// `null` alla primissima chiamata (serve un punto di riferimento
  /// precedente per calcolare la differenza).
  double? sampleCpuUsagePercent() {
    final idle = calloc<FILETIME>();
    final kernel = calloc<FILETIME>();
    final user = calloc<FILETIME>();

    try {
      final success = GetSystemTimes(idle, kernel, user);
      if (success == 0) return null; // chiamata fallita

      final idleTime = _fileTimeToInt(idle);
      final kernelTime = _fileTimeToInt(kernel);
      final userTime = _fileTimeToInt(user);

      double? usage;
      if (_lastIdle != null && _lastKernel != null && _lastUser != null) {
        final idleDelta = idleTime - _lastIdle!;
        // Su Windows il tempo "kernel" include già il tempo idle, quindi il
        // tempo totale è kernelDelta + userDelta (non serve sommare idle
        // di nuovo).
        final kernelDelta = kernelTime - _lastKernel!;
        final userDelta = userTime - _lastUser!;
        final totalDelta = kernelDelta + userDelta;

        if (totalDelta > 0) {
          usage = (1 - (idleDelta / totalDelta)) * 100;
          usage = usage.clamp(0, 100);
        }
      }

      _lastIdle = idleTime;
      _lastKernel = kernelTime;
      _lastUser = userTime;

      return usage;
    } finally {
      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    }
  }

  /// Ritorna RAM usata/totale in GB, o `null` se la lettura fallisce.
  ({double usedGb, double totalGb})? readMemory() {
    final statusPtr = calloc<MEMORYSTATUSEX>();
    try {
      statusPtr.ref.dwLength = sizeOf<MEMORYSTATUSEX>();
      final success = GlobalMemoryStatusEx(statusPtr);
      if (success == 0) return null;

      const bytesPerGb = 1024 * 1024 * 1024;
      final totalBytes = statusPtr.ref.ullTotalPhys;
      final availBytes = statusPtr.ref.ullAvailPhys;
      final usedBytes = totalBytes - availBytes;

      return (
        usedGb: usedBytes / bytesPerGb,
        totalGb: totalBytes / bytesPerGb,
      );
    } finally {
      calloc.free(statusPtr);
    }
  }

  int _fileTimeToInt(Pointer<FILETIME> ft) {
    // FILETIME è composto da due DWORD (32 bit unsigned ciascuno);
    // combinarli in un unico intero a 64 bit è il modo standard per
    // ottenerne il valore numerico completo.
    return (ft.ref.dwHighDateTime << 32) | ft.ref.dwLowDateTime;
  }

  /// Nome commerciale della CPU (es. "Intel(R) Core(TM) i7-9700K CPU @
  /// 3.60GHz"), letto dal registro — è lo stesso valore che Windows stesso
  /// mostra in Gestione dispositivi/Informazioni di sistema. È un dato
  /// statico (non cambia mentre l'app gira), quindi va letto una sola
  /// volta e non ad ogni campione.
  String? readCpuName() {
    final hKey = Win32RegistryUtils.openKey(
      HKEY_LOCAL_MACHINE,
      r'HARDWARE\DESCRIPTION\System\CentralProcessor\0',
    );
    if (hKey == null) return null;
    try {
      final name = Win32RegistryUtils.getStringValue(hKey, 'ProcessorNameString');
      return name?.trim();
    } finally {
      Win32RegistryUtils.closeKey(hKey);
    }
  }

  /// Numero di processori logici (thread) visti dal sistema operativo —
  /// anche questo statico, va letto una sola volta.
  int? readLogicalProcessorCount() {
    final info = calloc<SYSTEM_INFO>();
    try {
      GetSystemInfo(info);
      final count = info.ref.dwNumberOfProcessors;
      return count > 0 ? count : null;
    } finally {
      calloc.free(info);
    }
  }

  /// Stato batteria — solo per PC portatili: su desktop (il caso più
  /// comune per un PC da gaming) Windows non riporta nessuna batteria e
  /// questo ritorna `null`, che l'HUD interpreta come "nascondi l'icona".
  ({int percent, bool charging})? readBatteryStatus() {
    final status = calloc<SYSTEM_POWER_STATUS>();
    try {
      final result = GetSystemPowerStatus(status);
      if (result == 0) return null;

      final batteryFlag = status.ref.BatteryFlag;
      final percent = status.ref.BatteryLifePercent;
      // BatteryFlag 128 = "no system battery" (desktop), 255 = sconosciuto;
      // BatteryLifePercent 255 = sconosciuto. In entrambi i casi non c'è
      // un dato affidabile da mostrare.
      if (batteryFlag == 128 || batteryFlag == 255 || percent == 255) return null;

      // Bit 3 (valore 8) di BatteryFlag indica "in carica".
      final charging = (batteryFlag & 8) != 0;
      return (percent: percent, charging: charging);
    } catch (_) {
      return null;
    } finally {
      calloc.free(status);
    }
  }
}
