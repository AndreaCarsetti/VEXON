// VEXON Hardware Service
//
// Piccolo servizio in background che legge i sensori hardware reali
// (CPU/GPU/RAM) tramite LibreHardwareMonitorLib e li espone su un server
// HTTP locale, così l'app Flutter può leggerli con una semplice richiesta
// GET invece di dover integrare direttamente codice nativo Windows.
//
// Endpoint: http://127.0.0.1:5157/stats  → JSON con i valori correnti
//
// NOTA IMPORTANTE: molti sensori (soprattutto le temperature) richiedono
// privilegi di amministratore per essere letti — vedi app.manifest.
// Se lanci questo eseguibile senza i permessi giusti, il server risponde
// comunque ma alcuni valori potrebbero risultare a 0.

using System.Net;
using System.Text;
using System.Text.Json;
using LibreHardwareMonitor.Hardware;

const string ListenUrl = "http://127.0.0.1:5157/";

var computer = new Computer
{
    IsCpuEnabled = true,
    IsGpuEnabled = true,
    IsMemoryEnabled = true,
};
computer.Open();

var updateVisitor = new UpdateVisitor();

var listener = new HttpListener();
listener.Prefixes.Add(ListenUrl);

try
{
    listener.Start();
}
catch (HttpListenerException ex)
{
    Console.WriteLine($"Impossibile avviare il server su {ListenUrl}: {ex.Message}");
    Console.WriteLine("Probabile causa: un'altra istanza del servizio è già in esecuzione.");
    return;
}

Console.WriteLine($"VEXON Hardware Service avviato — in ascolto su {ListenUrl}stats");
Console.WriteLine("Premi CTRL+C per fermare il servizio.");

while (true)
{
    HttpListenerContext context;
    try
    {
        context = listener.GetContext(); // bloccante finché non arriva una richiesta
    }
    catch (HttpListenerException)
    {
        break; // listener chiuso (es. shutdown)
    }

    if (context.Request.Url?.AbsolutePath == "/stats")
    {
        var stats = ReadStats(computer, updateVisitor);
        WriteJson(context.Response, stats);
    }
    else if (context.Request.Url?.AbsolutePath == "/health")
    {
        WriteJson(context.Response, new { status = "ok" });
    }
    else
    {
        context.Response.StatusCode = 404;
        context.Response.Close();
    }
}

computer.Close();

// --- Funzioni di supporto ---

static HardwareStats ReadStats(Computer computer, UpdateVisitor visitor)
{
    computer.Accept(visitor); // aggiorna tutti i sensori (pattern ufficiale di LibreHardwareMonitor)

    float cpuUsage = 0, cpuTemp = 0, gpuUsage = 0, gpuTemp = 0, ramUsedGb = 0, ramTotalGb = 0;

    foreach (var hardware in computer.Hardware)
    {
        switch (hardware.HardwareType)
        {
            case HardwareType.Cpu:
                cpuUsage = FirstSensorValue(hardware, SensorType.Load, preferredNameContains: "Total") ?? cpuUsage;
                cpuTemp = FirstSensorValue(hardware, SensorType.Temperature, preferredNameContains: "Package") ?? cpuTemp;
                break;

            case HardwareType.GpuNvidia:
            case HardwareType.GpuAmd:
            case HardwareType.GpuIntel:
                gpuUsage = FirstSensorValue(hardware, SensorType.Load, preferredNameContains: "Core") ?? gpuUsage;
                gpuTemp = FirstSensorValue(hardware, SensorType.Temperature, preferredNameContains: "Core") ?? gpuTemp;
                break;

            case HardwareType.Memory:
                var used = FirstSensorValue(hardware, SensorType.Data, preferredNameContains: "Used");
                var available = FirstSensorValue(hardware, SensorType.Data, preferredNameContains: "Available");
                if (used is not null) ramUsedGb = used.Value;
                if (used is not null && available is not null) ramTotalGb = used.Value + available.Value;
                break;
        }
    }

    return new HardwareStats(cpuUsage, cpuTemp, gpuUsage, gpuTemp, ramUsedGb, ramTotalGb);
}

// Cerca il sensore del tipo richiesto; se più sensori corrispondono,
// preferisce quello il cui nome contiene [preferredNameContains]
// (es. "CPU Package" per la temperatura totale invece del singolo core),
// altrimenti prende il primo disponibile — copre hardware di vendor diversi
// senza dover elencare ogni possibile nome di sensore.
static float? FirstSensorValue(IHardware hardware, SensorType type, string preferredNameContains)
{
    ISensor? preferred = null;
    ISensor? fallback = null;

    foreach (var sensor in hardware.Sensors)
    {
        if (sensor.SensorType != type || sensor.Value is null) continue;
        fallback ??= sensor;
        if (sensor.Name.Contains(preferredNameContains, StringComparison.OrdinalIgnoreCase))
        {
            preferred = sensor;
            break;
        }
    }

    return (preferred ?? fallback)?.Value;
}

static void WriteJson(HttpListenerResponse response, object payload)
{
    var json = JsonSerializer.Serialize(payload);
    var buffer = Encoding.UTF8.GetBytes(json);
    response.ContentType = "application/json";
    response.ContentLength64 = buffer.Length;
    response.OutputStream.Write(buffer, 0, buffer.Length);
    response.Close();
}

record HardwareStats(
    float CpuUsagePercent,
    float CpuTempCelsius,
    float GpuUsagePercent,
    float GpuTempCelsius,
    float RamUsedGb,
    float RamTotalGb
);

// Pattern ufficiale suggerito dalla documentazione di LibreHardwareMonitorLib
// per aggiornare ricorsivamente hardware e sotto-hardware prima di leggere
// i sensori.
public class UpdateVisitor : IVisitor
{
    public void VisitComputer(IComputer computer) => computer.Traverse(this);

    public void VisitHardware(IHardware hardware)
    {
        hardware.Update();
        foreach (var subHardware in hardware.SubHardware)
            subHardware.Accept(this);
    }

    public void VisitSensor(ISensor sensor) { }
    public void VisitParameter(IParameter parameter) { }
}
