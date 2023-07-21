const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const FollowSymlinkError = fileinfo.FollowSymlinkError;
const kernel_stat = linux.Stat;
const print = std.debug.print;

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

const max_path_length = fs.MAX_PATH_BYTES;

const ReadMode = enum {
    FOLLOW_ALMOST_ALL,
    FOLLOW_ALL,
    ALLOW_MISSING,
    READ_ONE
};

const OutputMode = enum {
    QUIET,
    NORMAL,
    VERBOSE
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
    var suppress_newline = (args.flag("-n") or args.flag("--no-newline"));
    const find_all_but_last_link = (args.flag("-f") or args.flag("--canonicalize"));
    const find_all_links = (args.flag("-e") or args.flag("--canonicalize-existing"));
    const accept_missing_links = (args.flag("-m") or args.flag("--canonicalize-missing"));

    checkInconsistencies(quiet, silent, verbose, zero, suppress_newline, find_all_but_last_link, find_all_links, accept_missing_links);

    const positionals = args.positionals();
    if (positionals.len == 0) {
        std.debug.print("{s}: missing operand\n", .{application_name});
        std.os.exit(1);
    } else if (positionals.len > 2 and suppress_newline) {
        std.debug.print("{s}: ignoring --no-newline with multiple arguments\n", .{application_name});
        suppress_newline = false;
    }
    
    var read_mode: ReadMode = ReadMode.READ_ONE;
    if (find_all_but_last_link) read_mode = ReadMode.FOLLOW_ALMOST_ALL;
    if (find_all_links) read_mode = ReadMode.FOLLOW_ALL;
    if (accept_missing_links) read_mode = ReadMode.ALLOW_MISSING;

    var output_mode: OutputMode = OutputMode.NORMAL;
    if (verbose) output_mode = OutputMode.VERBOSE;
    if (quiet) output_mode = OutputMode.QUIET;

    var success = true;
    var terminator: []const u8 = "\n";
    if (suppress_newline) terminator = "";
    if (zero) terminator = "\x00";

    for (positionals) |positional| {
        const iteration_success = process_link(positional, terminator, read_mode, output_mode) catch false;
        success = iteration_success and success;
    }

    const exit_code = switch(success) {
        false => @as(u8, 1),
        true => 0
    };
    std.os.exit(exit_code);
}


fn checkInconsistencies(quiet: bool, silent: bool, verbose: bool, zero: bool, suppress_newline: bool, find_all_but_last_link: bool, find_all_links: bool, accept_missing_links: bool) void {
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

    if (quiet and verbose) {
        std.debug.print("Quiet and verbose flags cannot be active at the same time. Exiting.\n", .{});
        std.os.exit(1);
    }

}

fn process_link(link: []const u8, terminator: []const u8, read_mode: ReadMode, output_mode: OutputMode) !bool {
    var link_buffer: [max_path_length]u8 = undefined;
    var path_buffer: [max_path_length]u8 = undefined;
    var my_kernel_stat: kernel_stat = std.mem.zeroes(kernel_stat);
    const np_link = try strings.toNullTerminatedPointer(link, default_allocator);
    defer default_allocator.free(np_link);
    _ = linux.lstat(np_link, &my_kernel_stat);
    const exists = fileinfo.fileExists(my_kernel_stat);
    if (!exists) {
        if (read_mode == ReadMode.ALLOW_MISSING) {
            if (output_mode == OutputMode.QUIET) return true;
            if (fs.path.isAbsolute(link)) {
                std.debug.print("{s}{s}", .{link, terminator});
            } else {
                std.debug.print("{s}{s}", .{try fileinfo.getAbsolutePath(default_allocator, link, null), terminator});
            }
            return true;
        } else {
            if (output_mode == OutputMode.VERBOSE) {
                std.debug.print("{s}: {s}: No such file or directory{s}", .{application_name, link, terminator});
            }
            return false;
        }
    }

    const is_symlink = fileinfo.isSymlink(my_kernel_stat);
    if (!is_symlink) {
        if (read_mode == ReadMode.FOLLOW_ALMOST_ALL or read_mode == ReadMode.FOLLOW_ALL or read_mode == ReadMode.READ_ONE) {
            if (output_mode == OutputMode.VERBOSE) {
                std.debug.print("{s}: {s}: Not a link{s}", .{application_name, link, terminator});
            }
            return false;
        } else if (read_mode == ReadMode.ALLOW_MISSING) {
            if (output_mode != OutputMode.QUIET) {
                std.debug.print("{s}{s}", .{try std.os.realpath(link, &path_buffer), terminator});
            }
            return true;
        } else {
            unreachable;
        }
    }
    if (read_mode == ReadMode.READ_ONE) {
        const result = try std.fs.cwd().readLink(link, link_buffer[0..]);
        std.debug.print("{s}{s}", .{result, terminator});
        return true;
    } else if (read_mode == ReadMode.FOLLOW_ALMOST_ALL or read_mode == ReadMode.FOLLOW_ALL or read_mode == ReadMode.ALLOW_MISSING) {
        return try follow_symlinks(link, terminator, read_mode, output_mode);
    }
    unreachable;
}

fn follow_symlinks(link: []const u8, terminator: []const u8, read_mode: ReadMode, output_mode: OutputMode) !bool {
    const symlink_result = fileinfo.followSymlink(default_allocator, link, read_mode == ReadMode.FOLLOW_ALL);
    defer if (symlink_result.path != null) default_allocator.free(symlink_result.path.?);
    if (symlink_result.error_result != null) {
        const error_result = symlink_result.error_result.?;
        if (output_mode == OutputMode.QUIET) return false;
        if (error_result == FollowSymlinkError.TooManyLinks) {
            print("Too many links{s}", .{terminator});
        } else if (error_result == FollowSymlinkError.TargetDoesNotExist) {
            print("'{s}' does not exist{s}", .{symlink_result.path.?, terminator});
        } else if (error_result == FollowSymlinkError.NotLink) {
            print("Target is not a link{s}", .{terminator});
        } else if (error_result == FollowSymlinkError.UnknownError) {
            print("Unknown error encountered{s}", .{terminator});
        }
        return false;
    } else {
        if (output_mode != OutputMode.QUIET) print("{s}{s}", .{symlink_result.path.?, terminator});
        return true;
    }
}
