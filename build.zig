const std = @import("std");
const os = @import("builtin").os.tag;
const version = @import("version.zig");
const Builder = std.Build;

pub fn build(b: *Builder) void {
    const current_zig_version = @import("builtin").zig_version;
    if (current_zig_version.major != 0 or current_zig_version.minor < 14) {
        std.debug.print("This project does not compile with a Zig version <0.14.x. Exiting.", .{});
        std.os.exit(1);
    }

    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const basename = addExe(b, target, "basename");
    const chgrp = addExe(b, target,"chgrp");
    const chmod = addExe(b,target, "chmod");
    const chown = addExe(b, target,"chown");
    const cksum = addExe(b,target, "cksum");
    const dircolors = addExe(b,target, "dircolors");
    const dirname = addExe(b,target, "dirname");
    const echo = addExe(b,target, "echo");
    const false_app = addExe(b,target, "false");
    const fold = addExe(b, target,"fold");
    const groups = addExe(b, target,"groups");
    const hostid = addExe(b,target, "hostid");
    const hostname = addExe(b, target,"hostname");
    const id = addExe(b,target, "id");
    const kill = addExe(b,target, "kill");
    const link = addExe(b, target,"link");
    const logname = addExe(b, target,"logname");
    const md5sum = addExe(b,target, "md5sum");
    const mkdir = addExe(b, target,"mkdir");
    const mkfifo = addExe(b, target,"mkfifo");
    const mktemp = addExe(b, target,"mktemp");
    const nice = addExe(b,target, "nice");
    const nproc = addExe(b, target,"nproc");
    const printenv = addExe(b,target, "printenv");
    const pwd = addExe(b,target, "pwd");
    const readlink = addExe(b,target, "readlink");
    const realpath = addExe(b, target,"realpath");
    const rmdir = addExe(b,target, "rmdir");
    const sleep = addExe(b,target, "sleep");
    const sum = addExe(b, target,"sum");
    const sync = addExe(b, target,"sync");
    const touch = addExe(b,target, "true");
    const true_app = addExe(b,target, "true");
    const truncate = addExe(b, target, "truncate");
    const tty = addExe(b,target, "tty");
    const unlink = addExe(b,target, "unlink");
    const uname = addExe(b, target,"uname");
    const uptime = addExe(b,target, "uptime");
    const users = addExe(b, target,"users");
    const whoami = addExe(b,target, "whoami");
    const yes = addExe(b, target,"yes");

    _ = basename;
    _ = cksum;
    _ = dircolors;
    _ = dirname;
    _ = echo;
    _ = false_app;
    _ = fold;
    _ = hostname;
    _ = kill;
    _ = link;
    _ = md5sum;
    _ = mktemp;
    _ = pwd;
    _ = readlink;
    _ = realpath;
    _ = rmdir;
    _ = sleep;
    _ = sum;
    _ = sync;
    _ = touch;
    _ = true_app;
    _ = truncate;
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

fn addExe(b: *Builder, target: std.Build.ResolvedTarget, comptime name: []const u8) *Builder.Step.Compile {
    const exe = b.addExecutable(.{ .name = name, .target = target, .root_source_file = b.path("src/" ++ name ++ ".zig"), .optimize = .ReleaseSafe, .version = .{ .major = version.major, .minor = version.minor, .patch = version.patch } });
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    return exe;
}
