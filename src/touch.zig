const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const time = std.time;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const mode = @import("util/mode.zig");
const version = @import("util/version.zig");
const system = @import("util/system.zig");

const Allocator = std.mem.Allocator;
const mode_t = mode.mode_t;
const MakeFifoError = fileinfo.MakeFifoError;
const print = @import("util/print_tools.zig").print;
const pprint = @import("util/print_tools.zig").pprint;
const exit = os.exit;
const OpenError = fs.File.OpenError;

const allocator = std.heap.page_allocator;

const application_name = "touch";

const help_message =
\\Usage: touch [OPTION]... FILE...
\\Update the access and modification times of each FILE to the current time.
\\
\\A FILE argument that does not exist is created empty, unless -c or -h
\\is supplied.
\\
\\A FILE argument string of - is handled specially and causes touch to
\\change the times of the file associated with standard output.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -a                     change only the access time
\\  -c, --no-create        do not create any files
\\  -d, --date=STRING      parse STRING and use it instead of current time
\\  -h, --no-dereference   affect each symbolic link instead of any referenced
\\                         file (useful only on systems that can change the
\\                         timestamps of a symlink)
\\  -m                     change only the modification time
\\  -r, --reference=FILE   use this file's times instead of current time
\\  -t STAMP               use [[CC]YY]MMDDhhmm[.ss] instead of current time
\\      --time=WORD        change the specified time:
\\                           WORD is access, atime, or use: equivalent to -a
\\                           WORD is modify or mtime: equivalent to -m
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\Note that the -d and -t options accept different time-date formats.
;

var success = true;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-a") catch unreachable,
        clap.parseParam("-c, --no-create") catch unreachable,
        clap.parseParam("-d, --date <STR>") catch unreachable,
        clap.parseParam("-h, --no-dereference") catch unreachable,
        clap.parseParam("-m") catch unreachable,
        clap.parseParam("-r, --reference <STR>") catch unreachable,
        clap.parseParam("-t <STR>") catch unreachable,
        clap.parseParam("--time <STR>") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const arguments = args.positionals();

    const change_only_access_time = args.flag("-a");
    const create_if_not_exists = !args.flag("-c");
    const date_string = args.option("-d");
    const affect_symlink = args.flag("-h");
    const change_only_modification_time = args.flag("-m");
    const use_reference_file_time = args.option("-r");
    const use_timestamp = args.option("-t");
    const change_specified_attribute = args.option("--time");

    _ = change_specified_attribute;

    if (change_only_access_time and change_only_modification_time) {
        pprint("Cannot change only access time and only modification time. By default, both values are changed. Exiting.\n");
        exit(1);
    }

    if (arguments.len == 0) {
        pprint("At least one file needs to specified. Exiting.\n");
        exit(1);
    }

    var count_daterefs: u8 = 0;
    if (date_string != null) count_daterefs += 1;
    if (use_timestamp != null) count_daterefs += 1;
    if (use_reference_file_time != null) count_daterefs += 1;

    if (count_daterefs > 1) {
        pprint("Only one of date string, timestamp string, reference file allowed as a time basis. Exiting.\n");
        exit(1);
    }

    var change_access_time = !change_only_modification_time;
    var change_modification_time = !change_only_access_time;

    var reference_time_access: i128 = time.nanoTimestamp();
    var reference_time_mod: i128 = reference_time_access;

    if (date_string != null) {

    } else if (use_timestamp != null) {
        if (use_timestamp.?.len < 8) {
            pprint("Incorrect timestamp format supplied. Exiting.\n");
        }
    } else if (use_reference_file_time != null) {
        const reference_file = fs.cwd().openFile(use_reference_file_time.?, .{.mode = .read_only}) catch |err| {
            switch (err) {
                OpenError.FileNotFound => pprint("Reference file not found. Exiting.\n"),
                OpenError.AccessDenied => pprint("Access denied to reference file. Exiting.\n"),
                else => pprint("Unknown error occurred. Exiting.\n")
            }
            exit(1);
        };
        const meta_data = reference_file.metadata() catch {
            pprint("An unknown error occurred while processing the metadata of the reference file. Exiting.");
            exit(1);
        };
        reference_time_access = meta_data.accessed();
        reference_time_mod = meta_data.modified();
    }

    for (arguments) |path| {
        touch_file(path, create_if_not_exists, affect_symlink, change_access_time, change_modification_time, reference_time_access, reference_time_mod);
    }
}

fn touch_file(path: []const u8, create_if_not_exists: bool, affect_symlink: bool, change_access_time: bool, change_mod_time: bool, reference_time_access: i128, reference_time_mod: i128) void {
    _ = path; _ = create_if_not_exists; _ = affect_symlink; _ = change_access_time; _ = change_mod_time; _ = reference_time_access; _ = reference_time_mod;
}

