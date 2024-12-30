const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

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

pub fn main() !void {
        const allocator = std.heap.page_allocator;
        const params = comptime [_]clap.Param(clap.Help){
            clap.parseParam("--help display this help and exit") catch unreachable,
            clap.parseParam("--version  output version information and exit") catch unreachable,
            clap.parseParam("<STRING>") catch unreachable
        };

        var diag = clap.Diagnostic{};
        var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
        defer args.deinit();

        if (args.flag("--help")) {
            print(help_message, .{});
            std.posix.exit(0);
        } else if (args.flag("--version")) {
            version.printVersionInfo(application_name);
        } else {
            const arguments = try std.process.argsAlloc(allocator);
            if (arguments.len <= 2) {
                var outputted_text: []const u8 = undefined;
                if (arguments.len == 1) {
                    outputted_text = "y";
                } else {
                    outputted_text = arguments[1];
                }
                while (true) {
                    print("{s}\n", .{outputted_text});
                }
            }
            var prepared_size = arguments.len - 2;
            var i: usize = 1;
            while (i < arguments.len) {
                prepared_size += arguments[i].len;
                i += 1;
            }

            const outputted_text = try allocator.alloc(u8, prepared_size);
            strings.joinStrings(arguments, outputted_text);

            while(true) {
                print("{s}\n", .{outputted_text});
            }
        }
}
