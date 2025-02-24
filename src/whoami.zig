const std = @import("std");
const linux = std.os.linux;
const version = @import("util/version.zig");
const mem = std.mem;
const users = @import("util/users.zig");

const print = @import("util/print_tools.zig").print;
const clap2 = @import("clap2/clap2.zig");

const application_name = "whoami";

const help_message =
\\Usage: whoami [OPTION]...
\\Print the user name associated with the current effective user ID.
\\Same as id -un.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

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

    const positionals = parser.positionals();

    if (positionals.len > 0) {
        print("{s}: too many arguments", .{application_name});
        std.posix.exit(1);
    }

    const uid = linux.geteuid();
    const pw: *users.Passwd = users.getpwuid(uid);
    print("{s}\n", .{pw.pw_name});
    std.posix.exit(0);
}
