const std = @import("std");
const os = @import("builtin").os.tag;
const version = @import("version.zig");
const Builder = std.Build;

pub fn build(b: *Builder) void {
    const current_zig_version = @import("builtin").zig_version;
    if (current_zig_version.major != 0 or current_zig_version.minor < 10) {
        std.debug.print("This project does not compile with a Zig version <0.10.x. Exiting.", .{});
        std.os.exit(1);
    }

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const basename = addExe(b, "basename");
    const chgrp = addExe(b, "chgrp");
    const chmod = addExe(b, "chmod");
    const chown = addExe(b, "chown");
    const cksum = addExe(b, "cksum");
    const dircolors = addExe(b, "dircolors");
    const dirname = addExe(b, "dirname");
    const echo = addExe(b, "echo");
    const false_app = addExe(b, "false");
    const fold = addExe(b, "fold");
    const groups = addExe(b, "groups");
    const hostid = addExe(b, "hostid");
    const hostname = addExe(b, "hostname");
    const id = addExe(b, "id");
    const link = addExe(b, "link");
    const logname = addExe(b, "logname");
    const md5sum = addExe(b, "md5sum");
    const mkdir = addExe(b, "mkdir");
    const mkfifo = addExe(b, "mkfifo");
    const nice = addExe(b, "nice");
    const nproc = addExe(b, "nproc");
    const printenv = addExe(b, "printenv");
    const pwd = addExe(b, "pwd");
    const readlink = addExe(b, "readlink");
    const realpath = addExe(b, "realpath");
    const rmdir = addExe(b, "rmdir");
    const sleep = addExe(b, "sleep");
    const sum = addExe(b, "sum");
    const sync = addExe(b, "sync");
    const touch = addExe(b, "true");
    const true_app = addExe(b, "true");
    const tty = addExe(b, "tty");
    const unlink = addExe(b, "unlink");
    const uname = addExe(b, "uname");
    const uptime = addExe(b, "uptime");
    const users = addExe(b, "users");
    const whoami = addExe(b, "whoami");
    const yes = addExe(b, "yes");

    _ = basename;
    _ = cksum;
    _ = dircolors;
    _ = dirname;
    _ = echo;
    _ = false_app;
    _ = fold;
    _ = hostname;
    _ = link;
    _ = md5sum;
    _ = pwd;
    _ = readlink;
    _ = realpath;
    _ = rmdir;
    _ = sleep;
    _ = sum;
    _ = sync;
    _ = touch;
    _ = true_app;
    _ = unlink;
    _ = uname;
    _ = users;
    _ = yes;

    if (os == .linux) {
        chgrp.linkSystemLibrary("c");
        chmod.linkSystemLibrary("c");
        chown.linkSystemLibrary("c");
        groups.linkSystemLibrary("c");
        hostid.linkSystemLibrary("c");
        id.linkSystemLibrary("c");
        logname.linkSystemLibrary("c");
        mkdir.linkSystemLibrary("c");
        mkfifo.linkSystemLibrary("c");
        nice.linkSystemLibrary("c");
        nproc.linkSystemLibrary("c");
        printenv.linkSystemLibrary("c");
        tty.linkSystemLibrary("c");
        uptime.linkSystemLibrary("c");
        whoami.linkSystemLibrary("c");
    }
}

fn addExe(b: *Builder, comptime name: []const u8) *Builder.Step.Compile {
    const exe = b.addExecutable(.{ .name = name, .root_source_file = .{ .path = "src/" ++ name ++ ".zig" }, .optimize = .ReleaseSafe, .version = .{ .major = version.major, .minor = version.minor, .patch = version.patch } });
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    return exe;
}
