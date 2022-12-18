// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const c_time = @cImport({
    @cInclude("time.h");
});
pub const time_t = c_time.time_t;
pub const struct_tm = c_time.struct_tm;

const Case = std.fmt.Case;

pub fn getCurrentTime(input_time: *time_t) void {
    _ = c_time.time(input_time);
}

pub fn getCurrentTimeString(time: *time_t) [*:0]u8 {
    return c_time.ctime(time);
}

pub fn getLocalTimeStruct(time: *time_t) *struct_tm {
    return c_time.localtime(time);
}

pub fn getLocalTimeStructFromi32(time: i32) *struct_tm {
    var clong: c_long = undefined;
    clong = time;
    return getLocalTimeStruct(&clong);
}

pub fn toLocalDateTimeStringAlloc(alloc: std.mem.Allocator, local_time: *struct_tm) ![]const u8 {
    var result = try alloc.alloc(u8, 16);
    _ = std.fmt.bufPrintIntToSlice(result[0..4], @intCast(u32, local_time.tm_year + 1900), 10, Case.lower, std.fmt.FormatOptions{.width=4, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[5..7], @intCast(u32, local_time.tm_mon + 1), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[8..10], @intCast(u32, local_time.tm_mday), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[11..13], @intCast(u32, local_time.tm_hour), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[14..], @intCast(u32, local_time.tm_min), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    result[4] = '-';
    result[7] = '-';
    result[10] = ' ';
    result[13] = ':';
    return result;
}

pub fn toTimeStringAlloc(alloc: std.mem.Allocator, local_time: *struct_tm) ![]const u8 {
    var result = try alloc.alloc(u8, 8);
    _ = std.fmt.bufPrintIntToSlice(result[0..2], @intCast(u32, local_time.tm_hour), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[3..5], @intCast(u32, local_time.tm_min), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    _ = std.fmt.bufPrintIntToSlice(result[6..], @intCast(u32, local_time.tm_sec), 10, Case.lower, std.fmt.FormatOptions{.width=2, .fill='0'});
    result[2] = ':';
    result[5] = ':';
    return result;
}