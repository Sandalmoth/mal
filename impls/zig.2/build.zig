const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "step0_repl",
            .root_source_file = .{ .path = "src/step0_repl/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }

    {
        const exe = b.addExecutable(.{
            .name = "step1_read_print",
            .root_source_file = .{ .path = "src/step1_read_print/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }

    {
        const exe = b.addExecutable(.{
            .name = "step2_eval",
            .root_source_file = .{ .path = "src/step2_eval/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }

    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
}
