using System.Text.Json;
using CommonCopy.Core.Models;

namespace CommonCopy.Core.Services;

public sealed class JsonPhraseRepository
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly string? legacyDirectory;

    public JsonPhraseRepository(string? dataDirectory = null, string? legacyDataDirectory = null)
    {
        DataDirectory = dataDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CommonCopy");
        legacyDirectory = legacyDataDirectory ?? (dataDirectory is null
            ? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PhraseMenu")
            : null);
        DataPath = Path.Combine(DataDirectory, "phrases.json");
        BackupPath = Path.Combine(DataDirectory, "phrases.backup.json");
    }

    public string DataDirectory { get; }

    public string DataPath { get; }

    public string BackupPath { get; }

    public async Task<PhraseLibraryDocument> LoadAsync(CancellationToken cancellationToken = default)
    {
        await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            Directory.CreateDirectory(DataDirectory);
            await MigrateLegacyDataCoreAsync(cancellationToken).ConfigureAwait(false);

            if (!File.Exists(DataPath))
            {
                var defaults = DefaultPhraseLibrary.Create();
                await WriteAtomicCoreAsync(defaults, DataPath, createBackup: false, cancellationToken).ConfigureAwait(false);
                return defaults;
            }

            try
            {
                return await ReadAndValidateCoreAsync(DataPath, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception exception) when (exception is JsonException or InvalidDataException)
            {
                var corruptPath = Path.Combine(
                    DataDirectory,
                    $"phrases.corrupt-{DateTimeOffset.UtcNow:yyyyMMdd-HHmmss}.json");
                File.Copy(DataPath, corruptPath, overwrite: true);

                if (File.Exists(BackupPath))
                {
                    var recovered = await ReadAndValidateCoreAsync(BackupPath, cancellationToken).ConfigureAwait(false);
                    await WriteAtomicCoreAsync(recovered, DataPath, createBackup: false, cancellationToken).ConfigureAwait(false);
                    return recovered;
                }

                var defaults = DefaultPhraseLibrary.Create();
                await WriteAtomicCoreAsync(defaults, DataPath, createBackup: false, cancellationToken).ConfigureAwait(false);
                return defaults;
            }
        }
        finally
        {
            gate.Release();
        }
    }

    // Only the default application repository migrates. Preserve the old directory for rollback.
    // Never replace an existing CommonCopy library, including an existing invalid one.
    private async Task MigrateLegacyDataCoreAsync(CancellationToken cancellationToken)
    {
        if (legacyDirectory is null || File.Exists(DataPath))
        {
            return;
        }

        var oldLibrary = Path.Combine(legacyDirectory, "phrases.json");
        var oldBackup = Path.Combine(legacyDirectory, "phrases.backup.json");
        if (!File.Exists(oldLibrary) && !File.Exists(oldBackup))
        {
            return;
        }

        // A corrupt primary can be recovered from the last valid backup; never silently
        // initialize defaults over legacy user data if both copies are invalid.
        var source = oldLibrary;
        try
        {
            await ReadAndValidateCoreAsync(source, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception exception) when (exception is JsonException or InvalidDataException or FileNotFoundException)
        {
            source = oldBackup;
            if (!File.Exists(source))
            {
                throw new InvalidDataException("The existing PhraseMenu library could not be migrated. The original data has not been changed.", exception);
            }

            await ReadAndValidateCoreAsync(source, cancellationToken).ConfigureAwait(false);
        }

        var temporaryPath = Path.Combine(DataDirectory, $".phrases.migration-{Guid.NewGuid():N}.tmp");
        try
        {
            File.Copy(source, temporaryPath);
            // Move only when the destination does not exist. Existing CommonCopy data wins.
            File.Move(temporaryPath, DataPath);
            if (File.Exists(oldBackup) && !File.Exists(BackupPath))
            {
                File.Copy(oldBackup, BackupPath);
            }
        }
        finally
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
        }
    }

    public async Task SaveAsync(PhraseLibraryDocument document, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(document);
        PhraseLibraryValidator.EnsureValid(document);

        await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            Directory.CreateDirectory(DataDirectory);
            await WriteAtomicCoreAsync(document, DataPath, createBackup: true, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task ExportAsync(
        PhraseLibraryDocument document,
        string destinationPath,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(destinationPath);
        PhraseLibraryValidator.EnsureValid(document);

        await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var destinationDirectory = Path.GetDirectoryName(Path.GetFullPath(destinationPath));
            if (!string.IsNullOrEmpty(destinationDirectory))
            {
                Directory.CreateDirectory(destinationDirectory);
            }

            await WriteAtomicCoreAsync(document, destinationPath, createBackup: false, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task<PhraseLibraryDocument> ImportAsync(
        string sourcePath,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sourcePath);

        await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var imported = await ReadAndValidateCoreAsync(sourcePath, cancellationToken).ConfigureAwait(false);
            Directory.CreateDirectory(DataDirectory);
            await WriteAtomicCoreAsync(imported, DataPath, createBackup: true, cancellationToken).ConfigureAwait(false);
            return imported;
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task CreateBackupAsync(string destinationPath, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(destinationPath);

        await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (!File.Exists(DataPath))
            {
                throw new FileNotFoundException("No CommonCopy data file exists yet.", DataPath);
            }

            var destinationDirectory = Path.GetDirectoryName(Path.GetFullPath(destinationPath));
            if (!string.IsNullOrEmpty(destinationDirectory))
            {
                Directory.CreateDirectory(destinationDirectory);
            }

            File.Copy(DataPath, destinationPath, overwrite: true);
        }
        finally
        {
            gate.Release();
        }
    }

    public Task<PhraseLibraryDocument> RestoreBackupAsync(
        string sourcePath,
        CancellationToken cancellationToken = default) => ImportAsync(sourcePath, cancellationToken);

    private static async Task<PhraseLibraryDocument> ReadAndValidateCoreAsync(
        string path,
        CancellationToken cancellationToken)
    {
        await using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 16_384,
            FileOptions.Asynchronous | FileOptions.SequentialScan);

        var document = await JsonSerializer.DeserializeAsync<PhraseLibraryDocument>(
            stream,
            SerializerOptions,
            cancellationToken).ConfigureAwait(false);
        PhraseLibraryValidator.EnsureValid(document ?? throw new InvalidDataException("The phrase library is empty."));
        return document;
    }

    private static async Task WriteAtomicCoreAsync(
        PhraseLibraryDocument document,
        string destinationPath,
        bool createBackup,
        CancellationToken cancellationToken)
    {
        var fullDestinationPath = Path.GetFullPath(destinationPath);
        var destinationDirectory = Path.GetDirectoryName(fullDestinationPath)
            ?? throw new InvalidOperationException("The destination has no directory.");
        Directory.CreateDirectory(destinationDirectory);

        var temporaryPath = Path.Combine(
            destinationDirectory,
            $".{Path.GetFileName(destinationPath)}.{Guid.NewGuid():N}.tmp");

        try
        {
            await using (var stream = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 16_384,
                FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                await JsonSerializer.SerializeAsync(stream, document, SerializerOptions, cancellationToken)
                    .ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
            }

            if (createBackup && File.Exists(fullDestinationPath))
            {
                var backupPath = Path.Combine(destinationDirectory, "phrases.backup.json");
                File.Copy(fullDestinationPath, backupPath, overwrite: true);
            }

            File.Move(temporaryPath, fullDestinationPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }
}
