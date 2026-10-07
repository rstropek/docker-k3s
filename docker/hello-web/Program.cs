using System.Runtime.InteropServices;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();
var app = builder.Build();

// Who am I, and where? The answers change between your laptop and a container.
app.MapGet("/", (IConfiguration config, IHostEnvironment env) => new
{
    message = config["Greeting"] ?? "Hello",
    host = Environment.MachineName,
    os = RuntimeInformation.OSDescription,
    user = Environment.UserName,
    environment = env.EnvironmentName,
    dotnet = Environment.Version.ToString(),
    cpus = Environment.ProcessorCount,
    memoryLimitMb = GC.GetGCMemoryInfo().TotalAvailableMemoryBytes / 1024 / 1024,
});

// Configuration as the app sees it (step: environment variables)
app.MapGet("/config", (IConfiguration config) => new
{
    greeting = config["Greeting"],
    databaseHost = config["Database:Host"],
    connectionString = config.GetConnectionString("Default"),
});

// The request as the app sees it: behind a reverse proxy, the client is the proxy (step: Compose and Traefik)
app.MapGet("/request", (HttpContext http) => new
{
    remoteIp = http.Connection.RemoteIpAddress?.ToString(),
    scheme = http.Request.Scheme,
    host = http.Request.Host.ToString(),
    forwardedHeaders = http.Request.Headers
        .Where(h => h.Key.StartsWith("X-Forwarded-", StringComparison.OrdinalIgnoreCase))
        .ToDictionary(h => h.Key, h => h.Value.ToString()),
});

app.MapHealthChecks("/healthz");
app.MapOpenApi(); // /openapi/v1.json

// Allocate and keep memory to see a memory limit in action (step: monitoring)
var hog = new List<byte[]>();
app.MapGet("/alloc/{mb:int}", (int mb) =>
{
    for (var i = 0; i < mb; i++)
    {
        var block = new byte[1024 * 1024];
        Array.Fill(block, (byte)1); // touch every page, so the memory is really used
        hog.Add(block);
    }
    return new { allocatedMb = hog.Count };
});

// Crash on purpose to see exit codes and restart policies (step: monitoring)
app.MapGet("/crash", () =>
{
    _ = Task.Run(async () => { await Task.Delay(100); Environment.Exit(3); });
    return "Crashing with exit code 3...";
});

// Make graceful shutdown visible: docker stop sends SIGTERM, Ctrl+C sends SIGINT
app.Lifetime.ApplicationStopping.Register(() => Console.WriteLine("Stop signal received, shutting down gracefully"));

app.Run();
