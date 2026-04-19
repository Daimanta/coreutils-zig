const std = @import("std");
const fs = std.fs;
const os = std.os;
const testing = std.testing;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const custom_io = @import("util/io.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const exit = std.process.exit;

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


pub fn main(init: std.process.Init) !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
    };

    var parser = clap2.Parser.init(args, init.minimal, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        exit(0);
    }

    const arguments = parser.positionals();
    
    if (arguments.len == 0) {
        sumStdin(false, init.io);
    } else {
        for (arguments) |file| {
            if (std.mem.eql(u8, file, "-")) {
                if (!handled_stdin) {
                    sumStdin(true, init.io);
                    handled_stdin = true;
                }
            } else {
                sumFile(file, init.io);
            }
        }
    }
    
}

fn sumFile(file_path: []const u8, io: std.Io) void {
    var result: u32 = 0;
    var segments: u64 = 0;

    const file = std.Io.Dir.cwd().openFile(io, file_path, .{.mode = .read_only}) catch |err| {
        if (err == error.FileNotFound) {
            print("{s}: {s}: No such file or directory\n", .{application_name, file_path});
        } else {
            print("{s}: Unknown error encountered '{any}'\n", .{application_name, err});
        }
        return;
    };
    const file_size = file.length(io) catch unreachable;
    var algorithm = std.hash.crc.Crc32Cksum.init();
    const buffer_size: usize = 1 << 20;
    var buffer: [buffer_size]u8 = undefined;
    segments = file_size / buffer_size;
    if (file_size % buffer_size != 0) segments += 1;
    var i: usize = 0;
    while (i < segments): (i += 1) {
        const segment_size = file.readPositionalAll(io, buffer[0..], i * buffer_size) catch unreachable;
        algorithm.update(buffer[0..segment_size]);
    }
    result = algorithm.final();
    print("{d:0>5} {d: >5} {s}\n", .{result, file_size, file_path});
}

fn sumStdin(print_dash: bool, io: std.Io) void {
    const bytes = custom_io.readStdin(io, default_allocator) catch {
        print("Reading stdin failed\n", .{});
        return;
    };

    const result: u32 = std.hash.Crc32.hash(bytes);
    const dash = if (print_dash) "-" else "";
    print("{d:0>5} {d} {s}\n", .{result, bytes.len, dash});
    handled_stdin = true;
}
