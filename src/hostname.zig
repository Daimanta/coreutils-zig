const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const system = @import("util/system.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const SetHostnameError = system.SetHostnameError;

const allocator = std.heap.page_allocator;
const HOST_NAME_MAX = os.linux.HOST_NAME_MAX;
const print = @import("util/print_tools.zig").print;

const application_name = "hostname";

const help_message =
\\Usage: hostname [NAME]
\\  or:  hostname OPTION
\\Print or set the hostname of the current system.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
    };

    var parser = clap2.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const positionals = parser.positionals();

    if (positionals.len > 1) {
        print("Too many arguments. Exiting\n", .{});
        std.posix.exit(1);
    }

    if (positionals.len == 0) {
        var name_buffer: [HOST_NAME_MAX]u8 = undefined;
        const hostname = try std.posix.gethostname(&name_buffer);
        print("{s}\n", .{hostname});
        std.posix.exit(0);
    } else {
        system.setHostname(positionals[0]) catch |err| {
            const error_message = switch (err) {
                SetHostnameError.AccessDenied => "Root rights are required to change the hostname",
                SetHostnameError.InvalidAddress, SetHostnameError.NegativeLength => "Internal error",
                else => unreachable
            };
            print("{s}\n", .{error_message});
            std.posix.exit(1);
        };
        std.posix.exit(0);
    }

}
