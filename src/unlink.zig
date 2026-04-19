const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const UnlinkError = std.posix.UnlinkError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const exit = std.process.exit;

const application_name = "unlink";

const help_message =
\\Usage: unlink FILE
\\  or:  unlink OPTION
\\Call the unlink function to remove the specified FILE.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub fn main(init: std.process.Init) !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
    };

    var parser = clap2.Parser.init(args, init.minimal, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const positionals = parser.positionals();

    if (positionals.len > 2) {
        print("Too many arguments. Exiting\n", .{});
        exit(1);
    } else if (positionals.len == 0) {
        print("No file specified. Exiting\n", .{});
        exit(1);
    }

    const file_target = positionals[0];
    const file_target_null = try std.posix.toPosixPath(file_target);

    const result = std.os.linux.unlink(&file_target_null);
    if (result != 0) {
        print("Could not unlink\n", .{});
        exit(1);
    }
}
