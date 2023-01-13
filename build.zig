const std = @import("std");
const lj = @import("luajit.zig");

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

pub const lj_dir = thisDir() ++ "/LuaJIT";

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    //b.option([]const u8, "LUAJIT_DIR", "Path of LuaJIT source") orelse "LuaJIT";

    const exe = b.addExecutable("luajit", lj_dir ++ "/src/luajit.c");
    lj.addLuajit(exe) catch unreachable;
    exe.addIncludePath(lj_dir ++ "/src");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
}
