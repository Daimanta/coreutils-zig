// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const c_funcs = std.c;

const strings = @import("strings.zig");

const dlopen = c_funcs.dlopen;
const dlclose = c_funcs.dlclose;
const dlsym = c_funcs.dlsym;
const default_allocator = std.heap.page_allocator;

pub const OpenMode = enum(u8) {
    RTLD_LAZY = 1,
    RTLD_NOW = 0,
    RTLD_GLOBAL = 2,
    RTLD_LOCAL = 4
};


pub fn openDynamicLibrary(path: []const u8, openMode: OpenMode) !anyopaque {
    const pathN = try strings.toNullTerminatedPointer(path, default_allocator);
    defer default_allocator.free(pathN);
    const result = dlopen(pathN, @intFromEnum(openMode));
    return result orelse error.LinkingFailed;
}

pub fn closeDynamicLibrary(handle: anyopaque) !void {
    const returned = dlclose(handle);
    if (returned != null) {
        return error.ClosingLinkFailed;
    }
}

pub fn linkDynamicLibrarySymbol(handle: anyopaque, name: []const u8) !anyopaque {
    const nameN = try strings.toNullTerminatedPointer(name, default_allocator);
    defer default_allocator.free(nameN);
    return dlsym(handle, nameN) orelse error.NameNotFound;
}