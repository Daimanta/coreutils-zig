const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = std.posix.LinkError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const AT_SYMLINK_FOLLOW: i32 = 0x400;
const AT_EMPTY_PATH: i32 = 0x1000;

const application_name = "link";

const help_message =
\\Usage: link FILE1 FILE2
\\  or:  link OPTION
\\Call the link function to create a link named FILE2 to an existing FILE1.
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

    if (positionals.len != 2) {
        print("Exactly two files need to be specified. Exiting\n", .{});
        std.posix.exit(1);
    }

    const file_target = positionals[0];
    const file_source = positionals[1];

    if (file_source.len == 0 or file_target.len == 0) {
        print("{s}: cannot create link '{s}' to '{s}': No such file or directory\n", .{application_name, file_source, file_target});
        std.posix.exit(1);
    }

    std.posix.link(file_target, file_source) catch |err| {
        const error_message = switch (err) {
        LinkError.AccessDenied => "Access denied",
        LinkError.DiskQuota => "Disk quota exceeded",
        LinkError.FileSystem => "General file system error",
        LinkError.SymLinkLoop => "Symlink loop detected",
        LinkError.LinkQuotaExceeded => "Link quota exceeded",
        LinkError.NameTooLong => "Name too long",
        LinkError.FileNotFound => "File not found",
        LinkError.NoSpaceLeft => "No space left on device",
        LinkError.ReadOnlyFileSystem => "Read only filesystem encountered",
        LinkError.NotSameFileSystem => "Links are not on the same filesystem",
        else => "Unspecified error encountered"
        };
        print("{s}. Exiting\n", .{error_message});
        std.posix.exit(1);
    };
}
