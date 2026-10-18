const std = @import("std");
const os = @import("builtin").os.tag;
const version = @import("version.zig");
const Builder = std.Build;

pub fn build(b: *Builder) void {
    const current_zig_version = @import("builtin").zig_version;
    if (current_zig_version.major != 0 or current_zig_version.minor < 17) {
        std.debug.print("This project does not compile with a Zig version <0.17.x. Exiting.", .{});
        std.os.exit(1);
    }

    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const basename = addExe(b, target, "basename", false);
    const chgrp = addExe(b, target,"chgrp", true);
    const chmod = addExe(b,target, "chmod", true);
    const chown = addExe(b, target,"chown", true);
    const cksum = addExe(b,target, "cksum", false);
    const dircolors = addExe(b,target, "dircolors", false);
    const dirname = addExe(b,target, "dirname", false);
    const echo = addExe(b,target, "echo", false);
    const expand = addExe(b, target, "expand", false);
    const false_app = addExe(b,target, "false", false);
    const fold = addExe(b, target,"fold", false);
    const groups = addExe(b, target,"groups", true);
    const hostid = addExe(b,target, "hostid", true);
    const hostname = addExe(b, target,"hostname", false);
    const id = addExe(b,target, "id", true);
    const kill = addExe(b,target, "kill", false);
    const link = addExe(b, target,"link", false);
    const logname = addExe(b, target,"logname", true);
    const md5sum = addExe(b,target, "md5sum", false);
    const mkdir = addExe(b, target,"mkdir", true);
    const mkfifo = addExe(b, target,"mkfifo", true);
    const mktemp = addExe(b, target,"mktemp", false);
    const nice = addExe(b,target, "nice", true);
    const nproc = addExe(b, target,"nproc", true);
    const printenv = addExe(b,target, "printenv", true);
    const pwd = addExe(b,target, "pwd", false);
    const readlink = addExe(b,target, "readlink", false);
    const realpath = addExe(b, target,"realpath", false);
    const rmdir = addExe(b,target, "rmdir", false);
    const sleep = addExe(b,target, "sleep", false);
    const sum = addExe(b, target,"sum", false);
    const sync = addExe(b, target,"sync", false);
    const touch = addExe(b,target, "true", false);
    const true_app = addExe(b,target, "true", false);
    const truncate = addExe(b, target, "truncate", false);
    const tty = addExe(b,target, "tty", true);
    const unlink = addExe(b,target, "unlink", false);
    const uname = addExe(b, target,"uname", false);
    const uptime = addExe(b,target, "uptime", true);
    const users = addExe(b, target,"users", false);
    const whoami = addExe(b,target, "whoami", true);
    const yes = addExe(b, target,"yes", false);

    _ = basename;
    _ = cksum;
    _ = dircolors;
    _ = dirname;
    _ = echo;
    _ = expand;
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

    _ = chgrp;
    _ = chmod;
    _ = chown;
    _ = groups;
    _ = hostid;
    _ = id;
    _ = logname;
    _ = mkdir;
    _ = mkfifo;
    _ = nice;
    _ = nproc;
    _ = printenv;
    _ = tty;
    _ = uptime;
    _ = whoami;
}

fn addExe(b: *Builder, target: std.Build.ResolvedTarget, comptime name: []const u8, link_c: bool) *Builder.Step.Compile {
    const clap2 = b.dependency("clap2", .{
       .target = target,
       .optimize = .ReleaseSafe
    });

    const module = b.createModule(.{
        .root_source_file = b.path("src/" ++ name ++ ".zig"),
        .optimize = .ReleaseSafe,
        .target = target
    });
    if (link_c) {
        module.linkSystemLibrary("c", .{});
    }
    const exe = b.addExecutable(.{ .name = name, .root_module = module, .version = .{ .major = version.major, .minor = version.minor, .patch = version.patch } });
    exe.root_module.addImport("clap2", clap2.module("clap2"));
    if (link_c) {
        const c_stdlib_imports = b.addTranslateC(.{
            .root_source_file = b.path("src/util/c.h"),
            .target = target,
            .optimize = .ReleaseSafe,
        });
        exe.root_module.addImport("c_extends", c_stdlib_imports.createModule());
    }
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    return exe;
}
