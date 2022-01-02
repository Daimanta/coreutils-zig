const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const fileinfo = @import("util/fileinfo.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");
const time_info = @import("util/time.zig");
const utmp = @import("util/utmp.zig");

const Allocator = std.mem.Allocator;
const time_t = time_info.time_t;
const AccessError = os.AccessError;

const default_allocator = std.heap.page_allocator;
const print = std.debug.print;

const application_name = "fold";

const help_message =
\\Usage: fold [OPTION]... [FILE]...
\\Wrap input lines in each FILE, writing to standard output.
\\
\\With no FILE, or when FILE is -, read standard input.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -b, --bytes         count bytes rather than columns
\\  -s, --spaces        break at spaces
\\  -w, --width=WIDTH   use WIDTH columns instead of 80
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;

var handled_stdin = false;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-b, --bytes") catch unreachable,
        clap.parseParam("-s, --spaces") catch unreachable,
        clap.parseParam("-w, --width <INT>") catch unreachable,
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
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
    
    const wrap_bytes = args.flag("-b");
    const break_only_at_spaces = args.flag("-s");
    const width_string = args.option("-w");
    
    var width: u32 = 80;
    if (width_string != null) {
    
    }
    
    
    const positionals = args.positionals();
    
    if (positionals.len == 0) {
        print("{s}: No arguments supplied. Exiting.\n", .{application_name});
        return;
    }
    
    for (positionals) |arg| {
        try fold(arg, wrap_bytes, break_only_at_spaces, width);
    }
}

fn fold(path: []const u8, wrap_bytes: bool, break_only_at_spaces: bool, width: u32) !void {
    _ = wrap_bytes;

    const stat = fileinfo.getLstat(path) catch |err| {
        print("{s}\n", .{err});
        return;
    };
    if (!fileinfo.fileExists(stat)) {
        print("File '{s}' does not exist\n", .{path});
        return;
    }
    
    if (fileinfo.isDir(stat)) {
        print("'{s}' is a directory.\n", .{path});
        return;
    }
    
    const file_size = @intCast(u64, stat.size);
    
    const file = try fs.cwd().openFile(path, .{.read = true});
    
    
    var offset: usize = 0;
    const chunk_size: usize = 150;
    var file_buffer: [chunk_size]u8 = undefined;
    var start: usize = 0;
    var current_line_size: usize = 0;
    while (offset <= file_size) {
        const read = try file.pread(file_buffer[0..], offset);
        start = 0;
        while (start < read) {
            var runner = start;
            var terminated = false;
            var last_space = runner;
            while (runner < read and (current_line_size <= width)) {
                if (file_buffer[runner] == ' ') last_space = runner;
                if (file_buffer[runner] == '\n') {
                    print("{s}", .{file_buffer[start..runner+1]});
                    start = runner + 1;
                    current_line_size = 0;
                    terminated = true;
                    break;
                }
                runner += 1;
                current_line_size += 1;
            }
            if (!terminated) {
                if (runner == read) {
                    print("{s}", .{file_buffer[start..read]});
                    break;
                } else {
                    if (break_only_at_spaces) {
                        print("{s}\n", .{file_buffer[start..last_space]});
                        start = last_space + 1;
                        current_line_size = 0;
                    } else {
                        print("{s}\n", .{file_buffer[start..runner+1]});
                        start = runner + 1;
                        current_line_size = 0;
                    }
                }
            }
        }
        offset += chunk_size;
    }
    
}

