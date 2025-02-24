const std = @import("std");
const os = std.os;
const mem = std.mem;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "hostid";
const help_message =
\\Usage: hostid [OPTION]
\\Print the numeric identifier (in hexadecimal) for the current host.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

extern fn gethostid() callconv(.C) c_long;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
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

    const c_hostid = gethostid();
    const hostid: u32 = @intCast(c_hostid);
    print("{x:0>8}\n", .{hostid});

}
