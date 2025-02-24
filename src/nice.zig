const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");

const ChildProcess = std.process.Child;
const Allocator = std.mem.Allocator;
const PriorityType = system.PriorityType;
const SpawnError = ChildProcess.SpawnError;
const SetPriorityError = system.SetPriorityError;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

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
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.OptionArgument("n", &[_][]const u8{"adjustment"}, false),
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

    const arguments = parser.positionals();
    const adjustment_string = parser.option("n");

    if (arguments.len == 0 and !adjustment_string.found) {
        print("{d}\n", .{getpriority(@intFromEnum(PriorityType.PRIO_PROCESS), 0)});
        std.posix.exit(0);
    }

    var adjustment: i32 = 0;
    if (adjustment_string.found) {
        adjustment = std.fmt.parseInt(i32, adjustment_string.value.?, 10) catch {
            print("{s}: invalid number: '{s}'\n", .{application_name, adjustment_string.value.?});
            std.posix.exit(1);
        };
    }

    const effective_niceness: i32 = std.math.clamp(adjustment, system.MAXIMAL_NICENESS, system.MINIMAL_NICENESS);

    var child = ChildProcess.init(arguments[0..], allocator);
    try child.spawn();

    system.setPriority(PriorityType.PRIO_PROCESS, @as(u32, @intCast(child.id)), @as(c_int, @intCast(effective_niceness))) catch |err| {
        if (err == SetPriorityError.NoRightsForNiceValue) {
            print("{s}: cannot set niceness: Permission denied\n", .{application_name});
        } else {
            print("{s}: cannot set niceness: Unknown error occurred: '{?}'\n", .{application_name, err});
        }
    };

    _ = child.wait() catch |err| {
        if (err == SpawnError.FileNotFound) {
            print("{s}: '{s}': No such file or directory\n", .{application_name, arguments[0]});
        } else {
            print("{s}: '{s}': Unknown error occurred: '{?}'\n", .{application_name, arguments[0], err});
        }
        std.posix.exit(1);
    };
    _ = try child.kill();
}



