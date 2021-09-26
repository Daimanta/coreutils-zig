const std = @import("std");
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

pub fn indexOf(string: []const u8, byte: u8, result: *usize, found: *bool) void {
    found.* = false;
    for(string) |it, i| {
        if (it == byte) {
            result.* = i;
            found.* = true;
            break;
        }
    }
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