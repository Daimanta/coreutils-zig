// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const linux = std.os.linux;
const testing = std.testing;

pub const mode_t = linux.mode_t;
const default_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;

pub const SUID: u12 = 0o4000; // set user id
pub const SGID: u12 = 0o2000; // set group id
pub const SVTX: u12 = 0o1000; // sticky, t
pub const RUSR: u12 = 0o0400;
pub const WUSR: u12 = 0o0200;
pub const XUSR: u12 = 0o0100;
pub const RGRP: u12 = 0o0040;
pub const WGRP: u12 = 0o0020;
pub const XGRP: u12 = 0o0010;
pub const ROTH: u12 = 0o0004;
pub const WOTH: u12 = 0o0002;
pub const XOTH: u12 = 0o0001;

pub const ModeStruct = packed struct {
    xoth: bool,
    woth: bool,
    roth: bool,
    xgrp: bool,
    wgrp: bool,
    rgrp: bool,
    xusr: bool,
    wusr: bool,
    rusr: bool,
    svtx: bool,
    sgid: bool,
    suid: bool,
    _padding1: u4,
    _padding2: u16,

     pub fn init(mode: mode_t) ModeStruct {
         return @bitCast(@as(u32, @truncate(mode)));
     }

     pub fn to_mode(self: *const ModeStruct) mode_t {
        return @as(u32, @bitCast(self.*));
     }

     fn to_absolute_user_change(self: *const ModeStruct) AbsoluteChange {
        return AbsoluteChange{ .read = self.rusr, .write = self.wusr, .execute = self.xusr, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false };
     }

     fn to_absolute_group_change(self: *const ModeStruct) AbsoluteChange {
        return AbsoluteChange{ .read = self.rgrp, .write = self.wgrp, .execute = self.xgrp, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false };
     }

     fn to_absolute_other_change(self: *const ModeStruct) AbsoluteChange {
        return AbsoluteChange{ .read = self.roth, .write = self.woth, .execute = self.xoth, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false };
     }
};

pub const Operation = enum { ADD, REMOVE, SET };

pub const ChangeDerivation = enum { ABSOLUTE, RELATIVE };

pub const UserType = enum { USER, GROUP, OTHER };

pub const AbsoluteChange = struct { read: bool, write: bool, execute: bool, set_uid: bool, set_gid: bool, sticky: bool, set_global_bits: bool };

pub const ChangeSource = union(ChangeDerivation) { ABSOLUTE: AbsoluteChange, RELATIVE: UserType };

pub const ModeChange = struct { owner: bool, group: bool, other: bool, operation: Operation, source: ChangeSource };

pub const ModeError = error {
    InvalidModeString,
    UnknownError
};


pub fn applyModeChange(change: *const ModeChange, mode: *mode_t) void {
    const used_source: AbsoluteChange = getAbsoluteChange(change, mode);
    if (change.owner) updateUserType(mode, UserType.USER, change.operation, used_source);
    if (change.group) updateUserType(mode, UserType.GROUP, change.operation, used_source);
    if (change.other) updateUserType(mode, UserType.OTHER, change.operation, used_source);
}

fn getAbsoluteChange(change: *const ModeChange, mode: *mode_t) AbsoluteChange {
    switch (change.source) {
        ChangeSource.ABSOLUTE => {
            return change.source.ABSOLUTE;
        },
        ChangeSource.RELATIVE => {
            const mode_stct = ModeStruct.init(mode.*);
            switch (change.source.RELATIVE) {
                UserType.USER => {
                    return mode_stct.to_absolute_user_change();
                },
                UserType.GROUP => {
                    return mode_stct.to_absolute_group_change();
                },
                UserType.OTHER => {
                    return mode_stct.to_absolute_other_change();
                },
            }
        },
    }
}

fn updateUserType(mode: *mode_t, user: UserType, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (user) {
        UserType.USER => updateUser(mode, operation, absolute_change),
        UserType.GROUP => updateGroup(mode, operation, absolute_change),
        UserType.OTHER => updateOther(mode, operation, absolute_change),
    }
    if (absolute_change.set_global_bits) {
        var mode_stct = ModeStruct.init(mode.*);
        switch (operation) {
            Operation.SET => {
                mode_stct.suid = absolute_change.set_uid;
                mode_stct.sgid = absolute_change.set_gid;
                mode_stct.svtx = absolute_change.sticky;
            },
            Operation.ADD => {
                if (absolute_change.set_uid) mode_stct.suid = true;
                if (absolute_change.set_gid) mode_stct.sgid = true;
                if (absolute_change.sticky) mode_stct.svtx = true;
            },
            Operation.REMOVE => {
                if (absolute_change.set_uid) mode_stct.suid = false;
                if (absolute_change.set_gid) mode_stct.sgid = false;
                if (absolute_change.sticky) mode_stct.svtx = false;
            },
        }
        mode.* = mode_stct.to_mode();
    }
}

fn updateUser(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    var mode_stct = ModeStruct.init(mode.*);
    switch (operation) {
        Operation.SET => {
            mode_stct.rusr = absolute_change.read;
            mode_stct.wusr = absolute_change.write;
            mode_stct.xusr = absolute_change.execute;
        },
        Operation.ADD => {
            if (absolute_change.read) mode_stct.rusr = true;
            if (absolute_change.write) mode_stct.wusr = true;
            if (absolute_change.execute) mode_stct.xusr = true;
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode_stct.rusr = false;
            if (absolute_change.write) mode_stct.wusr = false;
            if (absolute_change.execute) mode_stct.xusr = false;
        },
    }
    mode.* = mode_stct.to_mode();
}

fn updateGroup(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    var mode_stct = ModeStruct.init(mode.*);
    switch (operation) {
        Operation.SET => {
            mode_stct.rgrp = absolute_change.read;
            mode_stct.wgrp = absolute_change.write;
            mode_stct.xgrp = absolute_change.execute;
        },
        Operation.ADD => {
            if (absolute_change.read) mode_stct.rgrp = true;
            if (absolute_change.write) mode_stct.wgrp = true;
            if (absolute_change.execute) mode_stct.xgrp = true;
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode_stct.rgrp = false;
            if (absolute_change.write) mode_stct.wgrp = false;
            if (absolute_change.execute) mode_stct.xgrp = false;
        },
    }
    mode.* = mode_stct.to_mode();
}

fn updateOther(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    var mode_stct = ModeStruct.init(mode.*);
    switch (operation) {
        Operation.SET => {
            mode_stct.roth = absolute_change.read;
            mode_stct.woth = absolute_change.write;
            mode_stct.xoth = absolute_change.execute;
        },
        Operation.ADD => {
            if (absolute_change.read) mode_stct.roth = true;
            if (absolute_change.write) mode_stct.woth = true;
            if (absolute_change.execute) mode_stct.xoth = true;
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode_stct.roth = false;
            if (absolute_change.write) mode_stct.woth = false;
            if (absolute_change.execute) mode_stct.xoth = false;
        },
    }
    mode.* = mode_stct.to_mode();
}

pub fn getModeFromString(string: []const u8, initial_mode: mode_t) ModeError!mode_t {
    var result: mode_t = initial_mode;
    var modifiers = ArrayList(ModeChange).init(default_allocator);
    defer modifiers.deinit();

    var tokenIterator = std.mem.tokenizeScalar(u8, string, ',');
    var items: u32 = 0;
    while (tokenIterator.next()) |_| {
        items += 1;
    }

    const single = items == 1;

    tokenIterator.reset();

    while (tokenIterator.next()) |token| {
        if (token.len == 0) return ModeError.InvalidModeString;

        var numerical = true;
        for (token, 0..) |byte, i| {
            if ((byte < '0' or byte > '9') and (i != 0 or (i == 0 and byte != '=' and byte != '+' and byte != '-'))) {
                numerical = false;
                break;
            }
        }
        if (numerical and (!single or token.len > 6)) {
            return ModeError.InvalidModeString;
        }

        if (numerical) {
            try handleNumber(token, &modifiers);
        } else {
            try handleString(token, &modifiers);
        }
    }
    
    for (modifiers.items) |item| {
        applyModeChange(&item, &result);
    }

    return result;
}

pub fn getModeFromStringAndZeroMode(string: []const u8) ModeError!mode_t {
    return getModeFromString(string, 0);
}

fn handleNumber(token: []const u8, modifiers: *ArrayList(ModeChange)) ModeError!void {
    const skip_first = (token[0] < '0' or token[0] > '9');
    const parsed_token = if (skip_first) token[1..] else token;
    var operation = Operation.SET;
    if (skip_first) {
        if (token[0] == '+') {
            operation = Operation.ADD;
        } else if (token[0] == '-') {
            operation = Operation.REMOVE;
        } 
    }
    
    const number = std.fmt.parseInt(u32, parsed_token, 8) catch return ModeError.InvalidModeString;
    if (number > 0o7777) {
        return ModeError.InvalidModeString;
    } else {
        var mode_stct = ModeStruct.init(number);
        const user_change: ModeChange = ModeChange{ .owner = true, .group = false, .other = false, .operation = operation, .source = ChangeSource{ .ABSOLUTE = mode_stct.to_absolute_user_change() } };
        const group_change: ModeChange = ModeChange{ .owner = false, .group = true, .other = false, .operation = operation, .source = ChangeSource{ .ABSOLUTE = mode_stct.to_absolute_group_change() } };
        const other_change: ModeChange = ModeChange{ .owner = false, .group = false, .other = true, .operation = operation, .source = ChangeSource{ .ABSOLUTE = mode_stct.to_absolute_other_change() } };

        const global_change: ModeChange = ModeChange{ .owner = false, .group = false, .other = false, .operation = operation, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = false, .write = false, .execute = false, .set_uid = number & SUID != 0, .set_gid = number & SGID != 0, .sticky = number & SVTX != 0, .set_global_bits = true } } };
                        
        modifiers.*.append(user_change) catch return ModeError.UnknownError;
        modifiers.*.append(group_change) catch return ModeError.UnknownError;
        modifiers.*.append(other_change) catch return ModeError.UnknownError;
        modifiers.*.append(global_change) catch return ModeError.UnknownError;
    }
}

fn handleString(token: []const u8, modifiers: *ArrayList(ModeChange)) ModeError!void {
    const first_mod = std.mem.indexOfAny(u8, token, "-+=");
    if (first_mod == null) return ModeError.InvalidModeString;
    const write_target = token[0..first_mod.?];
    var user = false;
    var group = false;
    var other = false;
    if (write_target.len == 0) {
        user = true;
        group = true;
        other = true;
    } else {
        for (write_target) |byte| {
            if (byte == 'a') {
                user = true;
                group = true;
                other = true;
            } else if (byte == 'u') {
                user = true;
            } else if (byte == 'g') {
                group = true;
            } else if (byte == 'o') {
                other = true;
            } else {
                return ModeError.InvalidModeString;
            }
        }
    }
    var mod_string = token[first_mod.?..];
    var mod_index: ?usize = 0;
    var next_index: ?usize = 0;
    while (mod_index != null) {
        if (mod_string.len == 1) return ModeError.InvalidModeString;
        var operation: Operation = undefined;
        if (mod_string[0] == '+') {
            operation = Operation.ADD;
        } else if (mod_string[0] == '=') {
            operation = Operation.SET;
        } else if (mod_string[0] == '-') {
            operation = Operation.REMOVE;
        } else {
            unreachable;
        }
        next_index = std.mem.indexOfAny(u8, mod_string[1..], "-+=");
        if (next_index != null) next_index.? += 1;
        var mod_sources: []const u8 = undefined;
        if (next_index == null) {
            mod_sources = mod_string[1..];
        } else {
            mod_sources = mod_string[1..next_index.?];
        }
        
        var read = false;
        var write = false;
        var execute = false;
        var set_uid = false;
        var set_gid = false;
        var sticky = false;
        
        var relative = false;
        
        for (mod_sources) |byte| {     
            if (byte == 'r') {
                read = true;
            } else if (byte == 'w') {
                write = true;
            } else if (byte == 'x') {
                execute = true;
            } else if (byte == 'X') {
                execute = true;
            } else if (byte == 's') {
                set_uid = true;
                set_gid = true;
            } else if (byte == 't') {
                sticky = true;
            } else if (byte == 'u') {
                if (mod_sources.len > 1) return ModeError.InvalidModeString;
                relative = true;
                const change = ModeChange{ .owner = user, .group = group, .other = other, .operation = operation, .source = ChangeSource{ .RELATIVE = UserType.USER } };
                modifiers.*.append(change) catch return ModeError.UnknownError;
                break;
            } else if (byte == 'g') {
                if (mod_sources.len > 1) return ModeError.InvalidModeString;
                relative = true;
                const change = ModeChange{ .owner = user, .group = group, .other = other, .operation = operation, .source = ChangeSource{ .RELATIVE = UserType.GROUP } };
                modifiers.*.append(change) catch return ModeError.UnknownError;
                break;
            } else if (byte == 'o') {
                if (mod_sources.len > 1) return ModeError.InvalidModeString;
                relative = true;
                const change = ModeChange{ .owner = user, .group = group, .other = other, .operation = operation, .source = ChangeSource{ .RELATIVE = UserType.OTHER } };
                modifiers.*.append(change) catch return ModeError.UnknownError;
                break;
            } else {
                return ModeError.InvalidModeString;
            }    
        }
        
        if (!relative) {
            const change = ModeChange{ .owner = user, .group = group, .other = other, .operation = operation, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = read, .write = write, .execute = execute, .set_uid = set_uid, .set_gid = set_gid, .sticky = sticky, .set_global_bits = true } } };
            modifiers.*.append(change) catch return ModeError.UnknownError;
        }
        
        mod_index = next_index;
        if (mod_index != null) mod_string = mod_string[mod_index.?..];
    }
}



test "set zero from struct" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange{ .owner = true, .group = true, .other = true, .operation = Operation.SET, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = false, .write = false, .execute = false, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false } } };
    applyModeChange(&mode_change, &mode);

    const expected: mode_t = 0;
    try testing.expectEqual(expected, mode);
}

test "set read from struct" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange{ .owner = true, .group = true, .other = true, .operation = Operation.SET, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = true, .write = false, .execute = false, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false } } };
    applyModeChange(&mode_change, &mode);

    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, mode);
}

test "set read and write from struct" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange{ .owner = true, .group = true, .other = true, .operation = Operation.SET, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = true, .write = true, .execute = false, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false } } };
    applyModeChange(&mode_change, &mode);

    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, mode);
}

test "set uid" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange{ .owner = true, .group = true, .other = true, .operation = Operation.SET, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = false, .write = false, .execute = false, .set_uid = true, .set_gid = false, .sticky = false, .set_global_bits = true } } };
    applyModeChange(&mode_change, &mode);

    const expected: mode_t = SUID;
    try testing.expectEqual(expected, mode);
}

test "add read to write" {
    var mode: mode_t = WUSR | WGRP | WOTH;
    const mode_change: ModeChange = ModeChange{ .owner = true, .group = true, .other = true, .operation = Operation.ADD, .source = ChangeSource{ .ABSOLUTE = AbsoluteChange{ .read = true, .write = false, .execute = false, .set_uid = false, .set_gid = false, .sticky = false, .set_global_bits = false } } };
    applyModeChange(&mode_change, &mode);

    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, mode);
}

test "mode number string parsing" {
    const result = try getModeFromStringAndZeroMode("755");
    const expected: mode_t = RUSR | WUSR | XUSR | RGRP | XGRP | ROTH | XOTH;
    try testing.expectEqual(expected, result);
}

test "add mode number" {
    const result = try getModeFromStringAndZeroMode("+4");
    const expected: mode_t = ROTH;
    try testing.expectEqual(expected, result);
}

test "mode set string parsing" {
    const result = try getModeFromStringAndZeroMode("a=rw");
    const expected: mode_t = RUSR | WUSR | RGRP | WGRP | ROTH | WOTH;
    try testing.expectEqual(expected, result);
}

test "invalid number mode" {
    _ = getModeFromStringAndZeroMode("10000") catch {
        return;
    };
    try testing.expect(false);
}

test "invalid combination of string and number" {
    _ = getModeFromStringAndZeroMode("a=rw,755") catch {
        return;
    };
    try testing.expect(false);
}

test "no modifier specified" {
    _ = getModeFromStringAndZeroMode("r") catch {
        return;
    };
    try testing.expect(false);
}

test "remove read" {
    const result = try getModeFromStringAndZeroMode("-r");
    const expected: mode_t = 0;
    try testing.expectEqual(expected, result);
}

test "add read" {
    const result = try getModeFromStringAndZeroMode("+r");
    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, result);
}

test "set read" {
    const result = try getModeFromStringAndZeroMode("=r");
    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, result);
}

test "set read and write" {
    const result = try getModeFromStringAndZeroMode("=rw");
    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, result);
}

test "set read add write" {
    const result = try getModeFromStringAndZeroMode("=r+w");
    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, result);
}

test "set other" {
    const result = try getModeFromStringAndZeroMode("=o");
    const expected: mode_t = 0;
    try testing.expectEqual(expected, result);
}

test "add read to other, set other" {
    const result = try getModeFromStringAndZeroMode("o+r,=o");
    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, result);
}

test "set read to all" {
    const result = try getModeFromStringAndZeroMode("a=r");
    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, result);
}

test "mode struct" {
    const value: mode_t = 6;
    const strct = ModeStruct.init(value);
    try testing.expect(strct.woth and strct.roth);
    const new_mode = strct.to_mode();
    try testing.expectEqual(value, new_mode);
}

