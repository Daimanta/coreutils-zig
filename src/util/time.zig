const std = @import("std");
const c_time = @cImport({
        @cInclude("time.h");
    });
pub const time_t = c_time.time_t;
pub const struct_tm = c_time.struct_tm;

pub fn get_current_time(input_time: *time_t) void {
    _ = c_time.time(input_time);
}

pub fn get_current_time_string(time: *time_t) [*:0]u8 {
    return c_time.ctime(time);
}

pub fn get_local_time_struct(time: *time_t) *struct_tm {
    return c_time.localtime(time);
}

pub fn to_time_string_alloc(alloc: *std.mem.Allocator, local_time: *struct_tm) ![]const u8 {
    var result = try alloc.alloc(u8, 8);
    _ = std.fmt.bufPrintIntToSlice(result[0..2], @intCast(u32, local_time.tm_hour), 10, false, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[3..5], @intCast(u32, local_time.tm_min), 10, false, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[6..], @intCast(u32, local_time.tm_sec), 10, false, std.fmt.FormatOptions{.width=2, .fill='0'});
    result[2] = ':';
    result[5] = ':';
    return result;
}