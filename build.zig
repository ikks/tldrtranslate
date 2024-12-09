const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn build(b: *std.Build) !void {
    const version = "1.0.1";
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    const lmdb = b.dependency("lmdb", .{
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "tldrtranslate",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("clap", clap.module("clap"));
    exe.root_module.addImport("lmdb", lmdb.module("lmdb"));
    exe.root_module.addOptions("config", options);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tldr-base.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    try distFn(b, options, optimize, clap);
}

///Build the app for each supported architecture
fn distFn(
    /// Build object
    b: *std.Build,
    /// Options to include version
    options: *std.Build.Step.Options,
    /// Options common to all archs-os
    optimize: std.builtin.OptimizeMode,
    /// clap is multiplatform, we can reuse it
    clap: *std.Build.Dependency,
) !void {
    const dist_step = b.step("dist", "Create distributable Files");
    var filename: []u8 = undefined;
    for (targets) |t| {

        // lmdb depends on the platform to be properly built
        const lmdb = b.dependency("lmdb", .{
            .target = b.resolveTargetQuery(t),
            .optimize = optimize,
        });
        filename = try distName(b.allocator, "tldrtranslate", t);
        const exe_dist = b.addExecutable(.{
            .name = filename,
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(t),
            .optimize = .ReleaseSmall,
        });
        defer b.allocator.free(filename);

        exe_dist.root_module.addImport("lmdb", lmdb.module("lmdb"));
        exe_dist.root_module.addImport("clap", clap.module("clap"));
        exe_dist.root_module.addOptions("config", options);

        const target_output = b.addInstallArtifact(exe_dist, .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        });

        dist_step.dependOn(&target_output.step);
    }
}

/// Builds a name based on the architecture and os and using the prefix, allocates memory
// that needs to be freed
fn distName(
    /// Deallocate the memory we use to return the result
    allocator: std.mem.Allocator,
    /// Name of the program
    prefix: []const u8,
    /// Architecture and OS expected to name the resulting file
    target: std.Target.Query,
) std.mem.Allocator.Error![]u8 {
    const arch_name = if (target.cpu_arch) |arch| @tagName(arch) else "native";
    const os_name = if (target.os_tag) |os_tag| @tagName(os_tag) else "native";

    const result = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ prefix, arch_name, os_name });
    return result;
}
