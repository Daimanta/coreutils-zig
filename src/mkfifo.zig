const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const UtType = utmp.UtType;
const time_t = time_info.time_t;

const allocator = std.heap.page_allocator;

const application_name = "mkfifo";

const help_message =
\\Usage: mkfifo [OPTION]... NAME...
\\Create named pipes (FIFOs) with the given NAMEs.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -m, --mode=MODE    set file permission bits to MODE, not a=rw - umask
\\  -Z                   set the SELinux security context to default type
\\      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux
\\                         or SMACK security context to CTX
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-m, --mode <STR>") catch unreachable,
        clap.parseParam("-Z") catch unreachable,
        clap.parseParam("--context <STR>") catch unreachable,
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

    const mode = args.option("-m");
    std.debug.print("{s}\n", .{mode});

}




