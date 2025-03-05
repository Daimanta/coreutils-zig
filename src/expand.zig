const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const exit = std.posix.exit;
const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "expand";

const help_message =
\\Usage: expand [OPTION]... [FILE]...
\\Convert tabs in each FILE to spaces, writing to standard output.
\\
\\With no FILE, or when FILE is -, read standard input.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -i, --initial    do not convert tabs after non blanks
\\  -t, --tabs=N     have tabs N characters apart, not 8
\\  -t, --tabs=LIST  use comma separated list of tab positions
\\                     The last specified position can be prefixed with '/'
\\                     to specify a tab size to use after the last
\\                     explicitly specified tab stop.  Also a prefix of '+'
\\                     can be used to align remaining tab stops relative to
\\                     the last specified tab stop instead of the first column
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

const default_tab_stops = 8;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("i", &[_][]const u8{"initial"}),
        clap2.Argument.OptionArgument("t", &[_][]const u8{"tabs"}, false),
    };

    var parser = clap2.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const arguments = parser.positionals();
    if (arguments.len == 0) {
        print("{s}: At least one file must be specified. Exiting.\n",.{application_name});
    }

    const initial = parser.flag("i");
    const tabs = parser.option("t");
    _ = initial; _ = tabs;

}
