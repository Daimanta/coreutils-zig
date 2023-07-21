const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;
const mem = std.mem;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const strings = @import("util/strings.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const kernel_stat = linux.kernel_stat;
const print = @import("util/print_tools.zig").print;

const application_name = "basename";
const help_message =
    \\Usage: basename NAME [SUFFIX]
    \\  or:  basename OPTION... NAME...
    \\Print NAME with any leading directory components removed.
    \\If specified, also remove a trailing SUFFIX.
    \\
    \\Mandatory arguments to long options are mandatory for short options too.
    \\  -a, --multiple       support multiple arguments and treat each as a NAME
    \\  -s, --suffix=SUFFIX  remove a trailing SUFFIX; implies -a
    \\  -z, --zero           end each output line with NUL, not newline
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\Examples:
    \\  basename /usr/bin/sort          -> "sort"
    \\  basename include/stdio.h .h     -> "stdio"
    \\  basename -s .h include/stdio.h  -> "stdio"
    \\
    \\
;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-a, --multiple") catch unreachable,
        clap.parseParam("-s, --suffix <SUFF>") catch unreachable,
        clap.parseParam("-z, --zero") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);

    if (args.flag("--help")) {
        print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    var multiple = (args.flag("-a") or args.flag("--multiple"));
    const suffix = args.option("-s");
    if (suffix != null) multiple = true;
    const zero = (args.flag("-z") or args.flag("--zero"));
    const newline = if (zero) "\x00" else "\n";

    const positionals = args.positionals();
    if (positionals.len == 0) {
        print("{s}: missing operand\n", .{application_name});
        std.os.exit(1);
    } else if (positionals.len > 2 and !multiple) {
        print("{s}: Only name and suffix expected\n", .{application_name});
        std.os.exit(1);
    }

    if (positionals.len == 2 and !multiple) {
        processFile(positionals[0], positionals[1], newline);
    } else {
        for (positionals) |pos| {
            processFile(pos, suffix, newline);
        }
    }
}

fn processFile(file: []const u8, suffix: ?[]const u8, newline: []const u8) void {
    var first_char: usize = undefined;
    var last_char: usize = undefined;
    if (file[file.len - 1] == '/') {
        var last_non_slash: ?usize = strings.lastNonIndexOf(file, '/');
        if (last_non_slash == null) {
            print("/{s}", .{newline});
            return;
        } else {
            last_char = last_non_slash.?;
            var next_slash = strings.lastIndexOf(file[0..last_char+1], '/');
            if (next_slash == null) first_char = 0 else first_char = next_slash.? + 1;
            stripSuffix(file[first_char..last_char+1], suffix, newline);
        }
    } else {
        var next_slash = strings.lastIndexOf(file[0..file.len], '/');
        if (next_slash == null) {
            stripSuffix(file, suffix, newline);
        } else {
            stripSuffix(file[next_slash.?+1..], suffix, newline);
        }
        return;
    }
}

fn stripSuffix(string: []const u8, suffix: ?[]const u8, newline: []const u8) void {
    if (suffix == null) {
        print("{s}{s}", .{string, newline});
    } else {
        if (mem.endsWith(u8, string, suffix.?)) {
            print("{s}{s}", .{string[0..string.len-suffix.?.len], newline});
        } else {
            print("{s}{s}", .{string, newline});
        }
    }
}
