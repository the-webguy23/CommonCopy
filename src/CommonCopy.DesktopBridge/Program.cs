using System.Text.Json;
using CommonCopy.DesktopBridge;

// One request per process. No network listener, shell execution, or content logging.
var json = new JsonSerializerOptions(JsonSerializerDefaults.Web);
try
{
    if (args.Length != 1) throw new InvalidOperationException();
    Directory.CreateDirectory(args[0]);
    // Serialize helper processes, including multiple app instances, before load/save.
    await using var lease = new FileStream(Path.Combine(args[0], ".desktop.lock"),
        FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
    var request = await JsonSerializer.DeserializeAsync<BridgeRequest>(Console.OpenStandardInput(), json)
        ?? throw new InvalidDataException();
    var state = await new BridgeService(args[0]).ExecuteAsync(request);
    await JsonSerializer.SerializeAsync(Console.OpenStandardOutput(), new { ok = true, state }, json);
}
catch (Exception)
{
    // Validation errors can include phrase titles. Return a fixed message instead.
    await JsonSerializer.SerializeAsync(Console.OpenStandardOutput(),
        new { ok = false, error = "The operation could not be completed. Check the fields, file, and whether another CommonCopy operation is running." }, json);
    Environment.ExitCode = 1;
}
