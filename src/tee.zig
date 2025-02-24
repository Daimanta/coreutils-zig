const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const time = std.time;

const clap2 = @import("clap2/clap2.zig");
const date_time = @import("util/datetime.zig");
const fileinfo = @import("util/fileinfo.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeFifoError = fileinfo.MakeFifoError;
const print = @import("util/print_tools.zig").print;
const pprint = @import("util/print_tools.zig").pprint;
const exit = os.exit;
const OpenError = fs.File.OpenError;
const parseInt = std.fmt.parseInt;
const eql = std.mem.eql;

const allocator = std.heap.page_allocator;

const application_name = "tee";

const help_message =
\\Usage: tee [OPTION]... [FILE]...
\\Copy standard input to each FILE, and also to standard output.
\\
\\  -a, --append              append to the given FILEs, do not overwrite
\\  -i, --ignore-interrupts   ignore interrupt signals
\\  -p                        diagnose errors writing to non pipes
\\      --output-error[=MODE]   set behavior on write error.  See MODE below
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\MODE determines behavior with write errors on the outputs:
\\  'warn'         diagnose errors writing to any output
\\  'warn-nopipe'  diagnose errors writing to any output not a pipe
\\  'exit'         exit on error writing to any output
\\  'exit-nopipe'  exit on error writing to any output not a pipe
\\The default MODE for the -p option is 'warn-nopipe'.
\\The default operation when --output-error is not specified, is to
\\exit immediately on error writing to a pipe, and diagnose errors
\\writing to non pipe outputs.
;

var success = true;

const output_error = enum {
    warn,
    warn_nopipe,
    exit,
    exit_nopipe
};


pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("a", &[_][]const u8{"append"}),
        clap2.Argument.FlagArgument("i", &[_][]const u8{"ignore-interrupts"}),
        clap2.Argument.OptionArgument(null, &[_][]const u8{"output-error"}, false)
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

    const arguments = parser.positionals();

    const append_files = parser.flag("a");
    const ignore_interrupts = parser.flag("i");
    const my_output_error = parser.option("output-error");
    _ = ignore_interrupts; _ = my_output_error;

    const stdin = std.io.getStdIn().reader();
    const bytes = stdin.readAllAlloc(allocator, 1 << 30) catch {
        print("Reading stdin failed. Exiting.\n", .{});
        std.posix.exit(1);
    };

    var output_error_mode = output_error.warn_nopipe;
    if (output_error != null) {
        if (std.mem.eql(u8, "warn", output_error.?)) {
            output_error_mode = output_error.warn;
        } else if (std.mem.eql(u8, "warn-nopipe", output_error.?)) {
            output_error_mode = output_error.warn;
        } else if(std.mem.eql(u8, "exit", output_error.?)) {
            output_error_mode = output_error.warn;
        } else if (std.mem.eql(u8, "exit-nopipe", output_error.?)) {
            output_error_mode = output_error.warn;
        } else {
            print("Unrecognized output error mode '%s'. Exiting.", .{output_error.?});
            std.posix.exit(1);
        }
    }

    for (arguments) |path| {
        write_to_file(path, bytes, append_files);
    }
}


fn write_to_file(path: []const u8, bytes: []const u8, append: bool) void {
    _ = bytes; _ = append;
    const stat = fileinfo.getLstat(path) catch |err| {
        print("{?}\n", .{err});
        return;
    };

    if (!fileinfo.fileExists(stat)) {
        //if (!create_if_not_exists) return;
        const file = fs.cwd().createFile(path, .{}) catch |err| {
            switch (err) {
                OpenError.AccessDenied => print("Access denied to '{s}'\n", .{path}),
                OpenError.FileNotFound => print("File '{s}' not found\n", .{path}),
                else => print("{?}\n", .{err}),
            }
            return;
        };
        defer file.close();
    }

}

fn touch_file(path: []const u8, create_if_not_exists: bool, affect_symlink: bool, change_access_time: bool, change_mod_time: bool, reference_time_access: i128, reference_time_mod: i128) void {
    //TODO: Affect symlink
    _ = affect_symlink; _ = change_access_time; _ = change_mod_time; _ = reference_time_access; _ = reference_time_mod;
    const stat = fileinfo.getLstat(path) catch |err| {
        print("{?}\n", .{err});
        return;
    };
    if (!fileinfo.fileExists(stat)) {
        if (!create_if_not_exists) return;
        const file = fs.cwd().createFile(path, .{}) catch |err| {
            switch (err) {
                OpenError.AccessDenied => print("Access denied to '{s}'\n", .{path}),
                OpenError.FileNotFound => print("File '{s}' not found\n", .{path}),
                else => print("{?}\n", .{err}),
            }
            return;
        };
        defer file.close();
        // update_times(file, change_access_time, change_mod_time, reference_time_access, reference_time_mod) catch |err| {
        //     print("{?}\n", .{err});
        //     return;
        // };
    } else {
        const file = fs.cwd().openFile(path, .{}) catch |err| {
            switch (err) {
                OpenError.AccessDenied => print("Access denied to '{s}'\n", .{path}),
                OpenError.FileNotFound => print("File '{s}' not found\n", .{path}),
                else => print("{?}\n", .{err}),
            }
            return;
        };
        defer file.close();
        // update_times(file, change_access_time, change_mod_time, reference_time_access, reference_time_mod) catch |err| {
        //     print("{?}\n", .{err});
        //     return;
        // };
    }
}


