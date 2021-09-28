const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "nproc";

const help_message =
\\Usage: nproc [OPTION]...
\\Print the number of processing units available to the current process,
\\which may be less than the number of online processors
\\
\\      --all      print the number of installed processors
\\      --ignore=N  if possible, exclude N processing units
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

extern fn get_nprocs() callconv(.C) c_int;
extern fn get_nprocs_conf() callconv(.C) c_int;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("--ignore <NUM>") catch unreachable,
        clap.parseParam("--all") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var ignore: u32 = 0;
    var all_processors = false;

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    if (args.flag("--all")) {
        all_processors = true;
    }

    if (args.option("--ignore")) |count| {
        var temp = std.fmt.parseInt(u32, count, 10) catch |err| {
            std.debug.print("{s}: invalid number: '{s}'\n", .{application_name, count});
            std.os.exit(1);
        };
        ignore = temp;
    }


    var result: u32 = 0;
    if (all_processors) {
        result = @intCast(u32, get_nprocs());
    } else {
        result = @intCast(u32, get_nprocs_conf());
    }
    if (ignore != 0) {
        result = std.math.max(1, result-ignore);
    }

    std.debug.print("{d}\n", .{result});
}
