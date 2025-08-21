const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const testing = std.testing;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;
const LinkError = os.LinkError;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
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

var handled_stdin = false;

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
            state +%= byte;
            state &= 0xffff;
        }
        self.state = @truncate(state);
    }

    pub fn final(self: *Self) u16 {
        return self.state;
    }

};

pub const SysVSum = struct {
    state: u32,
    const Self = @This();
    
    const RING_SIZE = 1 << 16;
    
    pub fn init() Self {
        return Self{ .state = 0};
    }

    pub fn update(self: *Self, input: []const u8) void {
        var state: u32 = self.state;
        for (input) |byte| {
            state +%= byte;
        }
        self.state = state;
    }

    pub fn final(self: *Self) u16 {
        const r = (self.state % RING_SIZE) + (self.state / RING_SIZE);
        return @truncate((r % RING_SIZE) + (r / RING_SIZE));
    }
};

pub const Algorithm = enum {
    BSD,
    SYSV
};

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("r", null),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"sysv"}),
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

    const bsd = parser.flag("r");
    const sysv = parser.flag("s");
    
    if (bsd and sysv) {
        print("-r and -s cannot be active at the same time\n", .{});
        std.posix.exit(1);
    }
    
    const algorithm = if (sysv) Algorithm.SYSV else Algorithm.BSD;
    
    const positionals = parser.positionals();
    const print_name = algorithm == Algorithm.SYSV or positionals.len > 1;
    
    if (positionals.len == 0) {
        sumStdin(algorithm);
    } else {
        for (positionals) |file| {
            if (std.mem.eql(u8, file, "-")) {
                if (!handled_stdin) {
                    sumStdin(algorithm);
                }
            } else {
                sumFile(file, algorithm, print_name);
            }
        }
    }
    
}

fn sumFile(file_path: []const u8, algorithm: Algorithm, print_name: bool) void {
    var result: u16 = 0;
    var segments: u64 = 0;

    const file = fs.cwd().openFile(file_path, .{.mode = .read_only}) catch |err| {
        if (err == error.FileNotFound) {
            print("{s}: {s}: No such file or directory\n", .{application_name, file_path});
        } else {
            print("{s}: Unknown error encountered '{?}'\n", .{application_name, err});
        }
        return;
    };
    const file_size = file.getEndPos() catch unreachable;
    
    if (algorithm == Algorithm.BSD) {
        const buffer_size: usize = 1024;
        var buffer: [buffer_size]u8 = undefined;
        segments = file_size / buffer_size;
        if (file_size % buffer_size != 0) segments += 1;

        var checksum = BsdSum.init();
        var i: usize = 0;

        while (i < segments): (i += 1) {
            const segment_size = file.preadAll(buffer[0..], i * buffer_size) catch unreachable;
            checksum.update(buffer[0..segment_size]);
        }
        result = checksum.final();
    } else if (algorithm == Algorithm.SYSV) {
        const buffer_size: usize = 512;
        var buffer: [buffer_size]u8 = undefined;
        segments = file_size / buffer_size;
        if (file_size % buffer_size != 0) segments += 1;

        var checksum = SysVSum.init();
        var i: usize = 0;

        while (i < segments): (i += 1) {
            const segment_size = file.preadAll(buffer[0..], i * buffer_size) catch unreachable;
            checksum.update(buffer[0..segment_size]);
        }
        result = checksum.final();
    } else {
        print("ERROR: Unrecognized algorithm, this shouldn't have happened.\n", .{});
    }
    
    
    print("{d:0>5} {d: >5}", .{result, segments});
    if (print_name) print(" {s}", .{file_path});
    print("\n", .{});
}

fn sumStdin(algorithm: Algorithm) void {
    const stdin = std.fs.File.stdin().deprecatedReader();
    const bytes = stdin.readAllAlloc(default_allocator, 1 << 30) catch {
        print("Reading stdin failed\n", .{});
        return;
    };
    
    var result: u16 = 0;
    var segments: u64 = 0;
    
    if (algorithm == Algorithm.BSD) {
        var checksum = BsdSum.init();
        checksum.update(bytes);
        result = checksum.final();
        segments = bytes.len / 1024;
        if (bytes.len % 1024 != 0) segments += 1;
    } else {
        var checksum = SysVSum.init();
        checksum.update(bytes);
        result = checksum.final();
        segments = bytes.len / 512;
        if (bytes.len % 512 != 0) segments += 1;
    }
    print("{d:0>5} {d: >5} -\n", .{result, segments});
    handled_stdin = true;
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
