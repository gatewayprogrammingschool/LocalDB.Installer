using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Management.Automation;
using System.Security;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.CommandLineUtils;

namespace GPS.LocalDb
{
    internal static class Program
    {
        public static void Main(params string[] args)
        {
            CommandLineApplication app = new(false);
            app.Name = "LocalDb Tool";
            app.Description = "Manage installation of LocalDb.";

            app.HelpOption("-?|-h|--help");

            app.Option(
                "-v",
                "Use Verbose Output.",
                CommandOptionType.NoValue,
                _ => { });

            app.Command("install", (command) =>
            {
                command.Description = "Install LocalDB from this machine.";
                command.HelpOption("-?|-h|--help");

                command.OnExecute(async () => await Install(app.Options).ConfigureAwait(false));
            });

            app.Command("uninstall", (command) =>
            {
                command.Description = "Uninstall LocalDB from this machine.";
                command.HelpOption("-?|-h|--help");

                command.OnExecute(async () => await Uninstall(app.Options).ConfigureAwait(false));
            });

            app.Execute(args);
        }

        private static async Task<int> Install(List<CommandOption> options)
        {
            _ = options[0];

            var shell = PowerShell.Create()
                            .AddCommand("Set-Location")
                            .AddParameter("-Path", "scripts")
                            .AddScript("./Install-LocalDB.ps1")
                            .AddParameter("-Verbose");

            using var result = await shell.InvokeAsync().ConfigureAwait(false);

            return 0;
        }

        private static async Task<int> Uninstall(List<CommandOption> options)
        {
            _ = options[0];

            var shell = PowerShell.Create()
                            .AddCommand("Set-Location")
                            .AddParameter("-Path", "scripts")
                            .AddScript("./Uninstall-LocalDB.ps1")
                            .AddParameter("-Verbose");

            using var result = await shell.InvokeAsync()
                                          .ConfigureAwait(false);

            return 0;
        }
    }
}
