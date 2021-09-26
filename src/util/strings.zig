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