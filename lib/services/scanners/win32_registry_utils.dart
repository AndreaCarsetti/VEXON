import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Accesso al registro di Windows tramite le API Win32 native
/// (RegOpenKeyEx/RegEnumKeyEx/RegQueryValueEx/RegCloseKey) invece del
/// wrapper `win32_registry`. Motivo: quel pacchetto ha cambiato più volte
/// i nomi dei propri metodi tra una versione minore e l'altra (in una
/// release "getSubkeys()", in un'altra una property diversa, poi
/// un'API completamente nuova nella v3) — impossibile scrivere codice
/// corretto contro un bersaglio così mobile senza poterlo compilare e
/// testare qui. Le funzioni Win32 grezze usate sotto, invece, sono la
/// vera API di sistema: esistono identiche da vent'anni e non cambiano.
class Win32RegistryUtils {
  /// Apre una chiave e ritorna il suo handle, o null se non esiste o
  /// l'accesso è negato. Il chiamante deve richiudere l'handle con
  /// [closeKey] quando ha finito.
  static int? openKey(int hive, String path) {
    final phkResult = calloc<HANDLE>();
    final pathPtr = path.toNativeUtf16();
    try {
      final result = RegOpenKeyEx(hive, pathPtr, 0, REG_SAM_FLAGS.KEY_READ, phkResult);
      if (result != WIN32_ERROR.ERROR_SUCCESS) return null;
      return phkResult.value;
    } finally {
      free(pathPtr);
      free(phkResult);
    }
  }

  static void closeKey(int hKey) => RegCloseKey(hKey);

  /// Elenca i nomi di tutte le sottochiavi dirette di [hKey].
  static List<String> enumSubkeyNames(int hKey) {
    final names = <String>[];
    // 256 caratteri sono ampiamente sufficienti: il limite Windows per un
    // nome di chiave è 255 caratteri.
    const bufferChars = 256;
    final nameBuffer = calloc<Uint16>(bufferChars).cast<Utf16>();
    final nameLen = calloc<DWORD>();

    try {
      var index = 0;
      while (true) {
        nameLen.value = bufferChars;
        final result = RegEnumKeyEx(
          hKey,
          index,
          nameBuffer,
          nameLen,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
        );
        if (result == WIN32_ERROR.ERROR_NO_MORE_ITEMS) break;
        if (result == WIN32_ERROR.ERROR_SUCCESS) {
          names.add(nameBuffer.toDartString());
        }
        // Un singolo indice illeggibile (nome troppo lungo, errore
        // transitorio) non deve bloccare l'enumerazione degli altri: si
        // salta e si prosegue comunque all'indice successivo.
        index++;
      }
    } finally {
      free(nameBuffer);
      free(nameLen);
    }

    return names;
  }

  /// Legge un valore stringa (REG_SZ / REG_EXPAND_SZ) dalla chiave aperta
  /// [hKey]. Ritorna null se il valore non esiste o non è una stringa.
  static String? getStringValue(int hKey, String valueName) {
    final valueNamePtr = valueName.toNativeUtf16();
    final dataType = calloc<DWORD>();
    final dataSize = calloc<DWORD>();

    try {
      // Prima chiamata solo per conoscere la dimensione del dato (si passa
      // nullptr come buffer) — pattern standard dell'API Win32 per i dati
      // di lunghezza variabile.
      var result = RegQueryValueEx(
        hKey,
        valueNamePtr,
        nullptr,
        dataType,
        nullptr,
        dataSize,
      );
      if (result != WIN32_ERROR.ERROR_SUCCESS || dataSize.value == 0) return null;

      // REG_SZ = 1, REG_EXPAND_SZ = 2 — unici tipi che ha senso leggere
      // come stringa qui.
      if (dataType.value != 1 && dataType.value != 2) return null;

      final buffer = calloc<Uint8>(dataSize.value);
      try {
        result = RegQueryValueEx(
          hKey,
          valueNamePtr,
          nullptr,
          dataType,
          buffer,
          dataSize,
        );
        if (result != WIN32_ERROR.ERROR_SUCCESS) return null;

        // I dati REG_SZ sono UTF-16 terminati da un carattere nullo.
        return buffer.cast<Utf16>().toDartString();
      } finally {
        free(buffer);
      }
    } finally {
      free(valueNamePtr);
      free(dataType);
      free(dataSize);
    }
  }
}
