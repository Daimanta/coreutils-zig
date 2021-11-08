// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub fn toNullTerminatedPointer(slice: []const u8, allocator_impl: *Allocator) ![:0]u8 {
    var result = try allocator_impl.alloc(u8, slice.len + 1);
    for (slice) |byte, i| {
        result[i] = slice[i];
    }
    result[result.len - 1] = 0;
    return result[0..result.len - 1:0];
}

pub fn convertOptionalSentinelString(ptr: [*:0]u8) ?[]u8 {
    if (@ptrToInt(ptr) == 0) {
        return null;
    } else {
        return std.mem.sliceTo(ptr, 0);
    }
}

pub fn indexOf(string: []const u8, match: u8) ?usize {
    for (string) |byte, i| {
        if (byte == match) return i;
    }
    return null;
}

pub fn indexOfStartOnPos(string: []const u8, start: usize, match: u8) ?usize {
    if (start >= string.len) return null;
    var i = start;
    while (i < string.len): (i += 1) {
        if (string[i] == match) return i;
    }
    return null;
}

pub fn lastIndexOf(string: []const u8, match: u8) ?usize {
    var i = string.len;
    while (i > 0) {
        i -= 1;
        if (string[i] == match) return i;
    }
    return null;
}

pub fn lastNonIndexOf(string: []const u8, match: u8) ?usize {
    var i = string.len;
    while (i > 0) {
        i -= 1;
        if (string[i] != match) return i;
    }
    return null;
}

pub fn joinStrings(input: [][]const u8, output: []u8) void {
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

pub fn insertStringAtIndex(dest: []u8, source: []const u8, start: *usize) void {
    std.mem.copy(u8, dest[start.*..start.*+source.len], source);
    start.* += source.len;
}

pub const StringBuilder = struct {
    buffer: []u8,
    insertion_index: usize,

    const Self = @This();
    pub fn init(buffer: []u8) Self {
        return Self{.buffer = buffer, .insertion_index = 0};
    }

    pub fn append(self: *Self, input: []const u8) void {
        insertStringAtIndex(self.buffer, input, &self.insertion_index);
    }
    
    pub fn appendBufPrint(self: *Self, comptime fmt: []const u8, args: anytype) void {
        const inserted = std.fmt.bufPrint(self.buffer[self.insertion_index..], fmt, args) catch return;
        self.insertion_index += inserted.len;
    }

    pub fn toSlice(self: *Self) []u8 {
        return self.buffer[0..self.insertion_index];
    }

    pub fn toOwnedSlice(self: *Self, allocator: *std.mem.Allocator) ![]u8 {
        var result = try allocator.alloc(u8, self.insertion_index);
        std.mem.copy(u8, result, self.buffer[0..self.insertion_index]);
        return result;
    }
};
