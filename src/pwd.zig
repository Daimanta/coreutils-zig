const std = @import("std");
const fs = std.fs;
const os = std.os;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "pwd";
const help_message =
\\pwd: pwd [-LP]
\\    Print the name of the current working directory.
\\
\\    Options:
\\      -L        print the value of $PWD if it names the current working
\\                directory
\\      -P        print the physical directory, without any symbolic links
\\      --version print the version
\\      --help    print this help message
\\    By default, `pwd' behaves as if `-L' were specified.
\\
\\    Exit Status:
\\    Returns 0 unless an invalid option is given or the current directory
\\    cannot be read.
\\
;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-L") catch unreachable,
        clap.parseParam("-P") catch unreachable
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var resolve_symlink = false;

    if (args.flag("--help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    } else if (args.flag("-L") and args.flag("-P")) {
        print("Conflicting options -L and -P set. Exiting.", .{});
        std.posix.exit(1);
    } else if (args.flag("-L")) {
        resolve_symlink = false;
    } else if (args.flag("-P")) {
        resolve_symlink = true;
    }

    if (resolve_symlink) {
        const result = fs.cwd();
        const path = try result.realpathAlloc(allocator, ".");
        print("{s}\n", .{path});
    } else {
        print("{s}\n", .{std.posix.getenv("PWD").?});
    }
}
