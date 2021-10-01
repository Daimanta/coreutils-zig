const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "readlink";
const help_message =
\\Usage: readlink [OPTION]... FILE...
\\Print value of a symbolic link or canonical file name
\\
\\  -f, --canonicalize            canonicalize by following every symlink in
\\                                every component of the given name recursively;
\\                                all but the last component must exist
\\  -e, --canonicalize-existing   canonicalize by following every symlink in
\\                                every component of the given name recursively,
\\                                all components must exist
\\  -m, --canonicalize-missing    canonicalize by following every symlink in
\\                                every component of the given name recursively,
\\                                without requirements on components existence
\\  -n, --no-newline              do not output the trailing delimiter
\\  -q, --quiet
\\  -s, --silent                  suppress most error messages (on by default)
\\  -v, --verbose                 report error messages
\\  -z, --zero                    end each output line with NUL, not newline
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;

const ReadMode = enum {
    FOLLOW_ALMOST_ALL,
    FOLLOW_ALL,
    ALLOW_MISSING,
    READ_ONE
};

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-f, --canonicalize") catch unreachable,
        clap.parseParam("-e, --canonicalize-existing") catch unreachable,
        clap.parseParam("-m, --canonicalize-missing") catch unreachable,
        clap.parseParam("-n, --no-newline") catch unreachable,
        clap.parseParam("-q, --quiet") catch unreachable,
        clap.parseParam("-s, --silent") catch unreachable,
        clap.parseParam("-v, --verbose") catch unreachable,
        clap.parseParam("-z, --zero") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);

    var resolve_symlink = false;

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const quiet = (args.flag("-q") or args.flag("--quiet"));
    const silent = (args.flag("-s") or args.flag("--silent"));
    const verbose = (args.flag("-v") or args.flag("--verbose"));
    const zero = (args.flag("-z") or args.flag("--zero"));
    const suppress_newline = (args.flag("-n") or args.flag("--no-newline"));
    const find_all_but_last_link = (args.flag("-f") or args.flag("--canonicalize"));
    const find_all_links = (args.flag("-e") or args.flag("--canonicalize-existing"));
    const accept_missing_links = (args.flag("-m") or args.flag("--canonicalize-missing"));

    checkInconsistencies(silent, verbose, zero, suppress_newline, find_all_but_last_link, find_all_links, accept_missing_links);

    const positionals = args.positionals();
    if (positionals.len == 0) {
        std.debug.print("{s}: missing operand\n", .{application_name});
        std.os.exit(1);
    }
    
    var mode: ReadMode = ReadMode.READ_ONE;
    if (find_all_but_last_link) mode = ReadMode.FOLLOW_ALMOST_ALL;
    if (find_all_links) mode = ReadMode.FOLLOW_ALL;
    if (accept_missing_links) mode = ReadMode.ALLOW_MISSING;

    var has_error = false;
    for (positionals) |positional| {
        has_error = process_link(positional, silent, verbose, zero, suppress_newline, mode) catch true or has_error;
    }

    const exit_code = switch(has_error) {
        true => @as(u8, 1),
        false => 0
    };
    std.os.exit(exit_code);
}


fn checkInconsistencies(silent: bool, verbose: bool, zero: bool, suppress_newline: bool, find_all_but_last_link: bool, find_all_links: bool, accept_missing_links: bool) void {
    if (silent and verbose) {
        std.debug.print("Silent and verbose flags cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }

    if (zero and suppress_newline) {
        std.debug.print("Zero delimiter and no delimiter cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }

    if (find_all_but_last_link and find_all_links) {
        std.debug.print("Canonicalize and canonicalize-existing cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }
    if (find_all_but_last_link and accept_missing_links) {
        std.debug.print("Canonicalize and canonicalize-missing cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }

    if (find_all_links and accept_missing_links) {
        std.debug.print("Canonicalize-existing and canonicalize-missing cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }

}


//    FOLLOW_ALMOST_ALL,
//    FOLLOW_ALL,
//    ALLOW_MISSING,
//    READ_ONE


fn process_link(link: []const u8, silent: bool, verbose: bool, zero: bool, suppress_newline: bool, mode: ReadMode) !bool {
    var buffer: [2 << 12]u8 = undefined;
    const kernel_stat = linux.kernel_stat;
    var my_kernel_stat: kernel_stat = undefined;
    const np_link = try strings.toNullTerminatedPointer(link, allocator);
    const lstat = linux.lstat(np_link, &my_kernel_stat);
    const is_symlink = fileinfo.isSymlink(my_kernel_stat);
    if (!is_symlink and mode == ReadMode.FOLLOW_ALMOST_ALL or mode == ReadMode.FOLLOW_ALL or mode == ReadMode.READ_ONE) {
        return false;
    }
    if (!is_symlink and mode == ReadMode.ALLOW_MISSING) {
        var path_buffer: [4096]u8 = undefined;
        std.debug.print("{s}\n", .{try std.os.realpath(link, &path_buffer)});
        return true;
    }
    return false;
}
