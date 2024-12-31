const std = @import("std");
const process = std.process;
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const default_allocator = std.heap.page_allocator;

const print = @import("util/print_tools.zig").print;

const help_message =
            \\Usage: yes [STRING]...
            \\ or:  yes OPTION
            \\Repeatedly output a line with all specified STRING(s), or 'y'.
            \\
            \\  --help     display this help and exit
            \\  --version  output version information and exit
            \\
            ;

const application_name = "yes";
const default_output_string = "y";

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
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

    const positionals = parser.positionals();
    if (positionals.len > 0) {
        const positionals_string = try std.mem.join(default_allocator, " ", positionals);
        while(true) {
            print("{s}\n", .{positionals_string});
        }
    } else {
        while(true) {
            print("{s}\n", .{default_output_string});
        }
    }
}
