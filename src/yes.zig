const std = @import("std");
const process = std.process;
const clap = @import("clap.zig");
const version = @import("util/version.zig");

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

        var iter = try clap.args.OsIterator.init(allocator);
        defer iter.deinit();
        var diag = clap.Diagnostic{};

        var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
            diag.report(std.io.getStdOut().writer(), err) catch {};
            return;
        };
        defer args.deinit();

        if (args.flag("--help")) {
            std.debug.print(help_message, .{});
            std.os.exit(0);
        } else if (args.flag("--version")) {
            version.print_version_info(application_name);
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
                    std.debug.print("{s}\n", .{outputted_text});
                }
            }
            var prepared_size = arguments.len - 2;
            var i: usize = 1;
            while (i < arguments.len) {
                prepared_size += arguments[i].len;
                i += 1;
            }

            var outputted_text = try allocator.alloc(u8, prepared_size);
            join_strings(arguments, outputted_text);

            while(true) {
                std.debug.print("{s}\n", .{outputted_text});
            }
        }
}

fn join_strings(input: [][]const u8, output: []u8) void {
    var walking_index: usize = 0;
    var i: usize = 1;
    while (i < input.len - 1) {
        for (input[i]) |byte| {
            output[walking_index] = byte;
            walking_index+=1;
        }
        output[walking_index] = ' ';
        walking_index += 1;
        i+=1;
    }
    for (input[input.len - 1]) |byte| {
        output[walking_index] = byte;
        walking_index+=1;
    }
}