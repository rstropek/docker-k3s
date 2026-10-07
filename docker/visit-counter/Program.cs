using Npgsql;

var builder = WebApplication.CreateBuilder(args);

// The connection string comes from configuration, e.g. ConnectionStrings__Visits in the environment
var connectionString = builder.Configuration.GetConnectionString("Visits")
    ?? throw new InvalidOperationException("Connection string 'Visits' is missing (set ConnectionStrings__Visits)");
builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionString));
builder.Services.AddHealthChecks();

var app = builder.Build();

// Create the table at startup. The advisory lock keeps two replicas from racing each other;
// it is held until the transaction commits, so the next replica already sees the table.
var db = app.Services.GetRequiredService<NpgsqlDataSource>();
await using (var cmd = db.CreateCommand("""
    SELECT pg_advisory_xact_lock(42);
    CREATE TABLE IF NOT EXISTS visits (id serial PRIMARY KEY, served_by text NOT NULL, at timestamptz NOT NULL DEFAULT now());
    """))
{
    await cmd.ExecuteNonQueryAsync();
}

var dbHost = new NpgsqlConnectionStringBuilder(connectionString).Host;

app.MapGet("/", async (NpgsqlDataSource db) =>
{
    await using (var insert = db.CreateCommand("INSERT INTO visits (served_by) VALUES ($1)"))
    {
        insert.Parameters.Add(new NpgsqlParameter { Value = Environment.MachineName });
        await insert.ExecuteNonQueryAsync();
    }
    await using var count = db.CreateCommand("SELECT count(*) FROM visits");
    var visits = (long)(await count.ExecuteScalarAsync())!;
    return new { visits, servedBy = Environment.MachineName, databaseHost = dbHost };
});

app.MapHealthChecks("/healthz");

app.Run();
