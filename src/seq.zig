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

const application_name = "seq";
const help_message =
\\Usage: seq [OPTION]... LAST
\\  or:  seq [OPTION]... FIRST LAST
\\  or:  seq [OPTION]... FIRST INCREMENT LAST
\\Print numbers from FIRST to LAST, in steps of INCREMENT.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -f, --format=FORMAT      use printf style floating-point FORMAT
\\  -s, --separator=STRING   use STRING to separate numbers (default: \n)
\\  -w, --equal-width        equalize width by padding with leading zeroes
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\If FIRST or INCREMENT is omitted, it defaults to 1.  That is, an
\\omitted INCREMENT defaults to 1 even when LAST is smaller than FIRST.
\\The sequence of numbers ends when the sum of the current number and
\\INCREMENT would become greater than LAST.
\\FIRST, INCREMENT, and LAST are interpreted as floating point values.
\\INCREMENT is usually positive if FIRST is smaller than LAST, and
\\INCREMENT is usually negative if FIRST is greater than LAST.
\\INCREMENT must not be 0; none of FIRST, INCREMENT and LAST may be NaN.
\\FORMAT must be suitable for printing one argument of type 'double';
\\it defaults to %.PRECf if FIRST, INCREMENT, and LAST are all fixed point
\\decimal numbers with maximum precision PREC, and to %g otherwise.
\\
\\
;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-f, --format <STR>") catch unreachable,
        clap.parseParam("-s, --separator <STR>") catch unreachable,
        clap.parseParam("-w, --equal-width") catch unreachable,
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

    const format = args.option("-f");
    const separator = args.option("-s");
    const equal_width = args.flag("-w");
    _ = format; _ = separator; _ = equal_width;


    const positionals = args.positionals();
    if (positionals.len == 0) {
        std.debug.print("{s}: At least one arguments needs to be specified\n", .{application_name});
        std.os.exit(1);
    } else if (positionals.len > 3) {
        std.debug.print("{s}: At most three arguments can be specified\n", .{application_name});
        std.os.exit(1);
    }

}

