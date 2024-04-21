const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const application_name = "kill";

const help_message =
\\Usage: kill [-s SIGNAL | -SIGNAL] PID...
\\  or:  kill -l [SIGNAL]...
\\  or:  kill -t [SIGNAL]...
\\Send signals to processes, or list signals.
\\  -s, --signal=SIGNAL, -SIGNAL
\\                   specify the name or number of the signal to be sent
\\  -l, --list       list signal names, or convert signal names to/from numbers
\\  -t, --table      print a table of signal information
\\      --help     display this help and exit
\\      --version  output version information and exit
\\  
\\SIGNAL may be a signal name like 'HUP', or a signal number like '1',
\\or the exit status of a process terminated by a signal.
\\PID is an integer; if negative it identifies a process group. 
\\
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-r") catch unreachable,
        clap.parseParam("-s, --signal") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    
}
