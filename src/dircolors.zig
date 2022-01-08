const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const defaults = @embedFile("../data/dircolors.defaults");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = std.debug.print;

const application_name = "dircolors";

const help_message =
    \\Usage: dircolors [OPTION]... [FILE]
    \\Output commands to set the LS_COLORS environment variable.
    \\
    \\Determine format of output:
    \\  -b, --sh, --bourne-shell    output Bourne shell code to set LS_COLORS
    \\  -c, --csh, --c-shell        output C shell code to set LS_COLORS
    \\  -p, --print-database        output defaults
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\If FILE is specified, read it to determine which colors to use for which
    \\file types and extensions.  Otherwise, a precompiled database is used.
    \\For details on the format of these files, run 'dircolors --print-database'.
    \\
    \\
;

const env_name: []const u8 = "LS_COLORS";

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-b, --sh") catch unreachable,
        clap.parseParam("--bourne-shell") catch unreachable,
        clap.parseParam("-c, --csh") catch unreachable,
        clap.parseParam("-p, --print-database") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }
    
    const bourne = args.flag("-b") or args.flag("--bourne-shell");
    const csh = args.flag("-c");
    const print_database = args.flag("-p");
    
    const flag_count = @boolToInt(bourne) + @boolToInt(csh) + @boolToInt(print_database);
    if (flag_count > 1) {
        print("A maximum of one of -b, -c, and -p is allowed. Exiting.\n", .{});
        os.exit(1);
    }
    
    const arguments = args.positionals();
    
    if (arguments.len > 1) {
        print("Either no argument, or one file needs to be specified. Exiting.\n", .{});
        os.exit(1);
    }
    
    if (arguments.len == 1) {
    
    } else {
        const env = os.getenv(env_name);
        if (env != null) {
            if (print_database) {
                print("{s}", .{defaults});
            } else if (csh) {
                print("setenv LS_COLORS '{s}'\n", .{env});
            } else {
                // Bourne shell implied
                print("LS_COLORS='{s}';\nexport LS_COLORS\n", .{env});
            }
            
        }
    }
    
}
