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

    {
        const exe = b.addExecutable(.{
            .name = "step3_env",
            .root_source_file = .{ .path = "src/step3_env/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }

    {
        const exe = b.addExecutable(.{
            .name = "step4_if_fn_do",
            .root_source_file = .{ .path = "src/step4_if_fn_do/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }
}
