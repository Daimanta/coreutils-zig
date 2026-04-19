const std = @import("std");

const exit = std.process.exit;

pub fn main(init: std.process.Init) !void {
    _ = init;
    exit(0);
}