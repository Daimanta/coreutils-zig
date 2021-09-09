const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const version = @import("util/version.zig");
const copyright = @import("util/copyright.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

        // First we specify what parameters our program can take.
        // We can use `parseParam` to parse a string to a `Param(Help)`
        const params = comptime [_]clap.Param(clap.Help){
            clap.parseParam("--help display this help and exit") catch unreachable,
            clap.parseParam("--version  output version information and exit") catch unreachable,
            clap.parseParam("<STRING>") catch unreachable
        };

        // We then initialize an argument iterator. We will use the OsIterator as it nicely
        // wraps iterating over arguments the most efficient way on each os.
        var iter = try clap.args.OsIterator.init(allocator);
        defer iter.deinit();

        // Initalize our diagnostics, which can be used for reporting useful errors.
        // This is optional. You can also just pass `null` to `parser.next` if you
        // don't care about the extra information `Diagnostics` provides.
        var diag = clap.Diagnostic{};

        var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
            // Report 'Invalid argument [arg]'
            diag.report(std.io.getStdOut().writer(), err) catch {};
            return;
        };
        defer args.deinit();

        if (args.flag("--help")) {
            const help_message =
            \\Usage: yes [STRING]...
            \\ or:  yes OPTION
            \\Repeatedly output a line with all specified STRING(s), or 'y'.
            \\
            \\  --help     display this help and exit
            \\  --version  output version information and exit
            \\
            ;
            std.debug.print(help_message, .{});
            std.os.exit(0);
        } else if (args.flag("--version")) {
            const name_info = "yes (Zig coreutils) ";
            std.debug.print(name_info, .{});
            std.debug.print("{d}.{d}.{d}\n", .{version.major, version.minor, version.patch});
            std.debug.print("{s}", .{copyright.license_info});
        } else {
            std.debug.print("{s}", .{args.positionals()[0]});
        }
}