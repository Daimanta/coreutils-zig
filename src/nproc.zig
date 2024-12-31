const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

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
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"all"}),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"ignore"}, false),
    };

    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    var ignore: u32 = 0;
    var all_processors = false;

    const all = parser.flag("all");
    const ignoreFlag = parser.option("ignore");

    if (all) {
        all_processors = true;
    }

    if (ignoreFlag.found) {
        const temp = std.fmt.parseInt(u32, ignoreFlag.value.?, 10) catch {
            print("{s}: invalid number: '{s}'\n", .{application_name, ignoreFlag.value.?});
            std.posix.exit(1);
        };
        ignore = temp;
    }


    var result: u32 = 0;
    if (all_processors) {
        result = @intCast(get_nprocs());
    } else {
        result = @intCast(get_nprocs_conf());
    }
    if (ignore != 0) {
        result = @max(1, result-ignore);
    }

    print("{d}\n", .{result});
}
