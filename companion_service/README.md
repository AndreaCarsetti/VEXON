# VEXON Hardware Service

Piccolo servizio .NET che legge i sensori hardware reali del PC (CPU/GPU/RAM)
e li espone su `http://127.0.0.1:5157/stats` in formato JSON, così l'app
Flutter può leggerli con una normale richiesta HTTP.

## Requisiti

- [.NET SDK 8.0](https://dotnet.microsoft.com/download) o successivo installato
  sul PC dove compili (non serve sul PC dell'utente finale, vedi sotto)

## Come compilarlo

```bash
cd companion_service
dotnet restore
dotnet build
```

Per testarlo subito senza pubblicare:

```bash
dotnet run
```

Poi apri http://127.0.0.1:5157/stats nel browser — dovresti vedere un JSON
tipo:

```json
{"cpuUsagePercent":23.4,"cpuTempCelsius":52.1,"gpuUsagePercent":8.0,"gpuTempCelsius":48.5,"ramUsedGb":9.2,"ramTotalGb":16.0}
```

**Se i valori di temperatura sono a 0**: quasi certamente il processo non ha
privilegi di amministratore. Riavvia il terminale come amministratore e
riprova. Nella build pubblicata (sotto) questo è già gestito dal manifest.

## Come pubblicarlo come eseguibile singolo

```bash
dotnet publish -c Release
```

Il risultato è un unico file `vexon_hardware_service.exe` in
`bin\Release\net8.0\win-x64\publish\` — self-contained (non serve installare
.NET sul PC del cliente) e con il manifest che richiede automaticamente i
permessi di amministratore all'avvio (comparirà il prompt UAC di Windows).

## Perché serve l'amministratore

LibreHardwareMonitorLib legge molti sensori (soprattutto le temperature)
attraverso driver di sistema a basso livello, che Windows protegge e rende
accessibili solo a processi elevati. Non c'è un modo per aggirare questo
requisito mantenendo l'accuratezza dei dati — è una limitazione della
libreria stessa, non di questa implementazione.

**Implicazione pratica per VEXON**: se il PC del gaming lounge ha l'account
utente configurato senza diritti di amministratore (comune in ambienti
condivisi/pubblici per motivi di sicurezza), il prompt UAC ad ogni avvio
potrebbe essere un problema. Opzioni da valutare più avanti:
- registrare il servizio come vera **attività pianificata di Windows** con
  "esegui con i privilegi più elevati" e "esegui indipendentemente dall'utente
  collegato" (evita il prompt visibile, ma va configurato una volta in fase
  di installazione)
- accettare il prompt UAC come parte del setup iniziale del PC (accettabile
  se il locale configura il PC una volta sola e poi lo lascia sempre acceso)

## Integrazione con l'app Flutter

Vedi `lib/services/hardware_monitor_service.dart` nel progetto principale —
la classe `HardwareMonitorService.companion()` fa polling di questo
endpoint ogni secondo. Se il servizio non risponde (non ancora avviato, o
in fase di sviluppo senza .NET), l'app Flutter torna automaticamente ai
dati mock invece di mostrare un errore.

## Prossimo passo: avvio automatico insieme all'app

Per ora questo servizio va avviato manualmente durante lo sviluppo
(`dotnet run`, o lanciando l'eseguibile pubblicato). Il passo successivo è
far sì che l'app VEXON principale lo avvii automaticamente come processo
in background al proprio avvio — vedi il TODO in
`lib/services/hardware_companion_launcher.dart` nel progetto Flutter.
