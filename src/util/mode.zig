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


pub const Operation = enum {
    ADD,
    REMOVE,
    SET
};

pub const ChangeDerivation = enum {
    ABSOLUTE,
    RELATIVE
};

pub const UserType = enum {
    USER,
    GROUP,
    OTHER
};

pub const AbsoluteChange = struct {
    read: bool,
    write: bool,
    execute: bool,
    set_uid: bool,
    set_gid: bool,
    sticky: bool,
    set_global_bits: bool
};

pub const ChangeSource = union(ChangeDerivation) {
    ABSOLUTE: AbsoluteChange,
    RELATIVE: UserType
};

pub const ModeChange = struct {
    owner: bool,
    group: bool,
    other: bool,
    operation: Operation,
    source: ChangeSource
};

pub fn applyModeChange(change: *const ModeChange, mode: *mode_t) void {
    var used_source: AbsoluteChange = getAbsoluteChange(change, mode);
    
    if (change.owner) updateUserType(mode, UserType.USER, change.operation, used_source);
    if (change.group) updateUserType(mode, UserType.GROUP, change.operation, used_source);
    if (change.group) updateUserType(mode, UserType.OTHER, change.operation, used_source);
}

fn getAbsoluteChange(change: *const ModeChange, mode: *mode_t) AbsoluteChange {
    switch(change.source) {
        ChangeSource.ABSOLUTE => {
            return change.source.ABSOLUTE;
        },
        ChangeSource.RELATIVE => {
            switch (change.source.RELATIVE) {
                    UserType.USER => {
                        return AbsoluteChange{
                            .read = mode.* & RUSR != 0,
                            .write = mode.* & WUSR != 0,
                            .execute = mode.* & XUSR != 0,
                            .set_uid = false,
                            .set_gid = false,
                            .sticky = false,
                            .set_global_bits = false
                        };
                    },
                    UserType.GROUP => {
                        return AbsoluteChange{
                            .read = false,
                            .write = false,
                            .execute = false,
                            .set_uid = false,
                            .set_gid = false,
                            .sticky = false,
                            .set_global_bits = false
                        };
                    },
                    UserType.OTHER => {
                        return AbsoluteChange{
                            .read = false,
                            .write = false,
                            .execute = false,
                            .set_uid = false,
                            .set_gid = false,
                            .sticky = false,
                            .set_global_bits = false
                        };
                    }
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
        switch (operation) {
            Operation.SET => {
                if (absolute_change.set_uid) mode.* |= SUID else mode.* &= ~SUID;
                if (absolute_change.set_gid) mode.* |= SGID else mode.* &= ~SGID;
                if (absolute_change.sticky) mode.* |= SVTX else mode.* &= ~SVTX;
            },
            Operation.ADD => {
                if (absolute_change.set_uid) mode.* |= SUID;
                if (absolute_change.set_gid) mode.* |= SGID;
                if (absolute_change.sticky) mode.* |= SVTX;
            },
            Operation.REMOVE => {
                if (absolute_change.set_uid) mode.* &= ~SUID;
                if (absolute_change.set_gid) mode.* &= ~SGID;
                if (absolute_change.sticky) mode.* &= ~SVTX;
            }
        }        
    }
}

fn updateUser(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= RUSR else mode.* &= ~RUSR;
            if (absolute_change.write) mode.* |= WUSR else mode.* &= ~WUSR;
            if (absolute_change.execute) mode.* |= XUSR else mode.* &= ~XUSR;
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= RUSR;
            if (absolute_change.write) mode.* |= WUSR;
            if (absolute_change.execute) mode.* |= XUSR;
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~RUSR;
            if (absolute_change.write) mode.* &= ~WUSR;
            if (absolute_change.execute) mode.* &= ~XUSR;
        }
    }
}

fn updateGroup(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= RGRP else mode.* &= ~RGRP;
            if (absolute_change.write) mode.* |= WGRP else mode.* &= ~WGRP;
            if (absolute_change.execute) mode.* |= XGRP else mode.* &= ~XGRP;        
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= RGRP;
            if (absolute_change.write) mode.* |= WGRP;
            if (absolute_change.execute) mode.* |= XGRP;            
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~RGRP;
            if (absolute_change.write) mode.* &= ~WGRP;
            if (absolute_change.execute) mode.* &= ~XGRP;            
        }
    }
}

fn updateOther(mode: *mode_t, operation: Operation, absolute_change: AbsoluteChange) void {
    switch (operation) {
        Operation.SET => {
            if (absolute_change.read) mode.* |= ROTH else mode.* &= ~ROTH;
            if (absolute_change.write) mode.* |= WOTH else mode.* &= ~WOTH;
            if (absolute_change.execute) mode.* |= XOTH else mode.* &= ~XOTH;        
        },
        Operation.ADD => {
            if (absolute_change.read) mode.* |= ROTH;
            if (absolute_change.write) mode.* |= WOTH;
            if (absolute_change.execute) mode.* |= XOTH;            
        },
        Operation.REMOVE => {
            if (absolute_change.read) mode.* &= ~ROTH;
            if (absolute_change.write) mode.* &= ~WOTH;
            if (absolute_change.execute) mode.* &= ~XOTH;            
        }
    }
}

pub fn getModeFromString (string:[]const u8) !mode_t {
    var result: mode_t = 0;
    var modifiers = ArrayList(ModeChange).init(default_allocator);
    defer modifiers.deinit();
    
    var tokenIterator = std.mem.tokenize(string, ",");
    var items: u32 = 0;
    while (tokenIterator.next()) |token| {
        items += 1;
    }
    
    const single = items == 1;
    
    tokenIterator.reset();
    
    while (tokenIterator.next()) |token| {
        if (token.len == 0) return error.InvalidModeString;
    
        var numerical = true;
        for (token) |byte| {
            if (byte < '0' or byte > '9') {
                numerical = false;
                break;
            }
        }
        if (numerical and (!single or token.len > 5)) {
            return error.InvalidModeString;
        }
    }
    
    for (modifiers.items) |item| {
        applyModeChange(&item, &result);
    }
    
    return result;
}

test "set zero" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.SET,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = false,
                .write = false,
                .execute = false,
                .set_uid = false,
                .set_gid = false,
                .sticky = false,
                .set_global_bits = false
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = 0;
    try testing.expectEqual(expected, mode);
}

test "set read" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.SET,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = true,
                .write = false,
                .execute = false,
                .set_uid = false,
                .set_gid = false,
                .sticky = false,
                .set_global_bits = false
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = RUSR | RGRP | ROTH;
    try testing.expectEqual(expected, mode);
}

test "set read and write" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.SET,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = true,
                .write = true,
                .execute = false,
                .set_uid = false,
                .set_gid = false,
                .sticky = false,
                .set_global_bits = false
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, mode);
}

test "set uid" {
    var mode: mode_t = 0;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.SET,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = false,
                .write = false,
                .execute = false,
                .set_uid = true,
                .set_gid = false,
                .sticky = false,
                .set_global_bits = true
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = SUID;
    try testing.expectEqual(expected, mode);
}

test "add read to write" {
    var mode: mode_t = WUSR | WGRP | WOTH;
    const mode_change: ModeChange = ModeChange {
        .owner = true,
        .group = true,
        .other = true,
        .operation = Operation.ADD,
        .source = ChangeSource {
            .ABSOLUTE = AbsoluteChange {
                .read = true,
                .write = false,
                .execute = false,
                .set_uid = false,
                .set_gid = false,
                .sticky = false,
                .set_global_bits = false
            }
        }
    };
    applyModeChange(&mode_change, &mode);
    
    const expected: mode_t = RUSR | RGRP | ROTH | WUSR | WGRP | WOTH;
    try testing.expectEqual(expected, mode);
}

test "mode number string parsing" {
    const result = try getModeFromString("755");
    const expected: mode_t = RUSR | WUSR | XUSR | RGRP | XGRP | ROTH | XOTH;
    try testing.expectEqual(expected, result);
}

test "mode set string parsing" {
    const result = try getModeFromString("a=rw");
    const expected: mode_t = RUSR | WUSR | RGRP | WGRP | ROTH | WOTH;
    try testing.expectEqual(expected, result);
}

test "invalid number mode" {
    const result = getModeFromString("100000") catch |err| {
        return;
    };
    try testing.expect(false);
}

test "invalid combination of string and number" {
    const result = getModeFromString("a=rw,755") catch |err| {
        return;
    };
    try testing.expect(false);
}