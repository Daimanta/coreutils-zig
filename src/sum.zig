const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const allocator = std.heap.page_allocator;
const application_name = "sum";

const help_message =
\\Usage: sum [OPTION]... [FILE]...
\\Print checksum and block counts for each FILE.
\\
\\With no FILE, or when FILE is -, read standard input.
\\
\\  -r              use BSD sum algorithm, use 1K blocks
\\  -s, --sysv      use System V sum algorithm, use 512 bytes blocks
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\
;

pub const BsdSum = struct {
    state: u16,
    const Self = @This();

    pub fn init() Self {
        return Self{ .state = 0};
    }

    pub fn update(self: *Self, input: []const u8) void {
        var state: u32 = self.state;
        for (input) |byte| {
            state = (state >> 1) + ((state & 1) << 15);
            state += byte;
            state &= 0xffff;
        }
        self.state = @truncate(u16, state);
    }

    pub fn final(self: *Self) u16 {
        return self.state;
    }

};

pub const Algorithm = enum {
    BSD,
    SYSV
};

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-r") catch unreachable,
        clap.parseParam("-s, --sysv") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var silent = false;

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const positionals = args.positionals();

    for (positionals) |file| {
        sumFile(file, Algorithm.BSD);
    }
}

fn sumFile(file_path: []const u8, algorithm: Algorithm) void {
    const file = fs.cwd().openFile(file_path, .{.read = true}) catch unreachable;
    const file_size = file.getEndPos() catch unreachable;
    const buffer_size: usize = 1024;
    var buffer: [buffer_size]u8 = undefined;
    const segments = file_size / buffer_size + 1;

    var checksum = BsdSum.init();
    var i: usize = 0;

    while (i < segments): (i += 1) {
        const segment_size = file.preadAll(buffer[0..], i * buffer_size) catch unreachable;
        checksum.update(buffer[0..segment_size]);
    }
    std.debug.print("{d}\t{d}\n", .{checksum.final(), segments});
}

test "bsd checksum empty string" {
    var checksum = BsdSum.init();
    checksum.update("");
    const expected: u16 = 0;
    try testing.expectEqual(expected, checksum.final());
}

test "bsd checksum example 1" {
    var checksum = BsdSum.init();
    checksum.update("abc");
    const expected: u16 = 16556;
    try testing.expectEqual(expected, checksum.final());
}