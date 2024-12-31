const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const UnlinkError = std.posix.UnlinkError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

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

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
    };

    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const positionals = parser.positionals();

    if (positionals.len > 2) {
        print("Too many arguments. Exiting\n", .{});
        std.posix.exit(1);
    } else if (positionals.len == 0) {
        print("No file specified. Exiting\n", .{});
        std.posix.exit(1);
    }

    const file_target = positionals[0];
    std.posix.unlink(file_target) catch |err| {
        const error_message = switch (err) {
            UnlinkError.AccessDenied => "Access denied",
            UnlinkError.FileBusy => "File is busy",
            UnlinkError.FileSystem => "Filesystem error",
            UnlinkError.IsDir => "Cannot unlink dir",
            UnlinkError.NameTooLong => "Name is too long",
            UnlinkError.FileNotFound => "File not found",
            else => "Unknown error"
        };
        print("{s}\n", .{error_message});
        std.posix.exit(1);
    };
}
