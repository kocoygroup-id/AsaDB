// Copyright (C) 2026 Kocoy Group and AsaDB contributors
// SPDX-License-Identifier: GPL-3.0-only
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

internal static class AsaDBLauncher
{
    private static int Main(string[] args)
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string appDir = Path.Combine(root, "app");
        string engine = Path.Combine(appDir, "AsA.exe");

        if (!File.Exists(engine))
        {
            Console.Error.WriteLine("AsaDB runtime tidak ditemukan: " + engine);
            Console.Error.WriteLine("Pastikan folder app tetap berada di sebelah AsaDB.exe.");
            Console.Error.WriteLine("Tekan Enter untuk keluar.");
            Console.ReadLine();
            return 1;
        }

        string arguments = args.Length == 0
            ? "panel \"..\\data\\asadb.asa\""
            : JoinArguments(args);

        var startInfo = new ProcessStartInfo
        {
            FileName = engine,
            Arguments = arguments,
            WorkingDirectory = appDir,
            UseShellExecute = false
        };

        try
        {
            using (Process process = Process.Start(startInfo))
            {
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("AsaDB gagal dijalankan: " + ex.Message);
            Console.Error.WriteLine("Tekan Enter untuk keluar.");
            Console.ReadLine();
            return 1;
        }
    }

    private static string JoinArguments(string[] args)
    {
        var builder = new StringBuilder();
        for (int i = 0; i < args.Length; i++)
        {
            if (i > 0)
            {
                builder.Append(' ');
            }
            builder.Append(Quote(args[i]));
        }
        return builder.ToString();
    }

    private static string Quote(string value)
    {
        if (value.Length == 0)
        {
            return "\"\"";
        }

        bool needsQuotes = value.IndexOfAny(new[] { ' ', '\t', '\n', '\r', '"' }) >= 0;
        if (!needsQuotes)
        {
            return value;
        }

        var builder = new StringBuilder();
        builder.Append('"');
        int slashCount = 0;
        foreach (char c in value)
        {
            if (c == '\\')
            {
                slashCount++;
                continue;
            }

            if (c == '"')
            {
                builder.Append('\\', slashCount * 2 + 1);
                builder.Append('"');
                slashCount = 0;
                continue;
            }

            if (slashCount > 0)
            {
                builder.Append('\\', slashCount);
                slashCount = 0;
            }
            builder.Append(c);
        }

        if (slashCount > 0)
        {
            builder.Append('\\', slashCount * 2);
        }
        builder.Append('"');
        return builder.ToString();
    }
}
