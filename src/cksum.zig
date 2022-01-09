const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const application_name = "cksum";

const help_message =
\\Usage: cksum [FILE]...
\\  or:  cksum [OPTION]
\\Print CRC checksum and byte counts of each FILE. This algorithm uses the IEEE polynomial and takes only the bytes of the data into consideration. This contrasts with GNU coreutils which does some postprocessing resulting in other hash values.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

var handled_stdin = false;


pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
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
    
    
    const arguments = args.positionals();
    
    if (arguments.len == 0) {
        sumStdin(false);
    } else {
        for (arguments) |file| {
            if (std.mem.eql(u8, file, "-")) {
                if (!handled_stdin) {
                    sumStdin(true);
                    handled_stdin = true;
                }
            } else {
                sumFile(file);
            }
        }
    }
    
}

fn sumFile(file_path: []const u8) void {
    var result: u32 = 0;
    var segments: u64 = 0;

    const file = fs.cwd().openFile(file_path, .{.read = true}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("{s}: {s}: No such file or directory\n", .{application_name, file_path});
        } else {
            std.debug.print("{s}: Unknown error encountered '{s}'\n", .{application_name, err});
        }
        return;
    };
    const file_size = file.getEndPos() catch unreachable;
    var algorithm = std.hash.crc.Crc32WithPoly(@intToEnum(std.hash.crc.Polynomial,0x04C11DB7)).init();
    const buffer_size: usize = 1 << 20;
    var buffer: [buffer_size]u8 = undefined;
    segments = file_size / buffer_size;
    if (file_size % buffer_size != 0) segments += 1;
    var i: usize = 0;
    while (i < segments): (i += 1) {
        const segment_size = file.preadAll(buffer[0..], i * buffer_size) catch unreachable;
        algorithm.update(buffer[0..segment_size]);
    }
    result = algorithm.final();
    std.debug.print("{d:0>5} {d: >5} {s}\n", .{result, file_size, file_path});
}

fn sumStdin(print_dash: bool) void {
    const stdin = std.io.getStdIn().reader();
    const bytes = stdin.readAllAlloc(default_allocator, 1 << 30) catch {
        std.debug.print("Reading stdin failed\n", .{});
        return;
    };
    var result: u32 = std.hash.Crc32.hash(bytes);
    var dash = if (print_dash) "-" else "";
    std.debug.print("{d:0>5} {d} {s}\n", .{result, bytes.len, dash});
    handled_stdin = true;
}
