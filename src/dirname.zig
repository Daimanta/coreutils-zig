const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const mem = std.mem;

const print = @import("util/print_tools.zig").print;

const help_message =
\\Usage: dirname [OPTION] NAME...
\\Output each NAME with its last non-slash component and trailing slashes
\\removed; if NAME contains no /'s, output '.' (meaning the current directory).
\\
\\  -z, --zero     end each output line with NUL, not newline
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\Examples:
\\  dirname /usr/bin/          -> "/usr"
\\  dirname dir1/str dir2/str  -> "dir1" followed by "dir2"
\\  dirname stdio.h            -> "."
\\
;

const application_name = "dirname";

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("z", &[_][]const u8{"zero"}),
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

    const use_null = parser.flag("z");
    const positionals = parser.positionals();

    for (positionals[0..]) |elem| {
        if (elem.len == 0 or elem[0] != '-') {
            processPath(elem, use_null);
        }
    }
    std.posix.exit(0);
}

fn processPath(path: []const u8, use_null: bool) void {
    if (path.len == 0) {
        print(".", .{});
    } else {
        var i: usize = path.len - 1;
        if (path[i] == '/' and i > 0) {
            i -= 1;
        }
        while (i > 0) {
            if (path[i] == '/') break;
            i -= 1;
        }

        if (i == 0) {
            if (path[0] == '/') {
                print("/", .{});
            } else {
                print(".", .{});
            }
        } else {
            var j = i;
            while (j >= 0) {
                j -= 1;
                if (j != '/') break;
            }
            print("{s}", .{path[0..j+1]});
        }
    }

    if (use_null) {
        print("\x00", .{});
    } else {
        print("\n", .{});
    }

}
