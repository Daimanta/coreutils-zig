const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");

const ChildProcess = std.ChildProcess;
const Allocator = std.mem.Allocator;
const PriorityType = system.PriorityType;
const SpawnError = ChildProcess.SpawnError;
const SetPriorityError = system.SetPriorityError;

const allocator = std.heap.page_allocator;

const DEFAULT_NICENESS = 10;
const application_name = "nice";

const help_message =
\\Usage: nice [OPTION] [COMMAND [ARG]...]
\\Run COMMAND with an adjusted niceness, which affects process scheduling.
\\With no COMMAND, print the current niceness.  Niceness values range from
\\-20 (most favorable to the process) to 19 (least favorable to the process).
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -n, --adjustment=N   add integer N to the niceness (default 10)
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\NOTE: your shell may have its own version of nice, which usually supersedes
\\the version described here.  Please refer to your shell's documentation
\\for details about the options it supports.
\\
\\
;


extern fn getpriority(which: c_int, who: system.id_t) c_int;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-n, --adjustment <NUM>") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();


    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const arguments = args.positionals();
    const adjustment_string = args.option("-n");

    if (arguments.len == 0 and adjustment_string == null) {
        std.debug.print("{d}\n", .{getpriority(@intFromEnum(PriorityType.PRIO_PROCESS), 0)});
        std.os.exit(0);
    }

    var adjustment: i32 = 0;
    if (adjustment_string != null) {
        adjustment = std.fmt.parseInt(i32, adjustment_string.?, 10) catch {
            std.debug.print("{s}: invalid number: '{s}'\n", .{application_name, adjustment_string.?});
            std.os.exit(1);
        };
    }

    var effective_niceness: i32 = adjustment;
    if (effective_niceness > system.MINIMAL_NICENESS) effective_niceness = system.MINIMAL_NICENESS;
    if (effective_niceness < system.MAXIMAL_NICENESS) effective_niceness = system.MAXIMAL_NICENESS;

    var child = ChildProcess.init(arguments[0..], allocator);
    try child.spawn();

    system.setPriority(PriorityType.PRIO_PROCESS, @intCast(u32, child.pid), @intCast(c_int, effective_niceness)) catch |err| {
        if (err == SetPriorityError.NoRightsForNiceValue) {
            std.debug.print("{s}: cannot set niceness: Permission denied\n", .{application_name});
        } else {
            std.debug.print("{s}: cannot set niceness: Unknown error occurred: '{?}'\n", .{application_name, err});
        }
    };

    _ = child.wait() catch |err| {
        if (err == SpawnError.FileNotFound) {
            std.debug.print("{s}: '{s}': No such file or directory\n", .{application_name, arguments[0]});
        } else {
            std.debug.print("{s}: '{s}': Unknown error occurred: '{?}'\n", .{application_name, arguments[0], err});
        }
        std.os.exit(1);
    };
    _ = try child.kill();
}



