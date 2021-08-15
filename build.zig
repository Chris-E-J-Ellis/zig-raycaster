const Builder = @import("std").build.Builder;
const std = @import("std");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("raycast", "src/main.zig");
    exe.setTarget(target);

    exe.linkSystemLibrary("c");
    exe.addIncludeDir("deps/include");
    exe.addLibPath("deps/lib");

    exe.addObjectFile("deps/lib/libSDL2.a");
    exe.addObjectFile("deps/lib/libncursesw.a");

    // I'm not entirely sure what I'm doing in the build currently,
    // but this will sort my two use cases for the moment =D
    if (std.Target.current.os.tag == .windows) {
        exe.linkSystemLibrary("ole32");
        exe.linkSystemLibrary("oleaut32");
        exe.linkSystemLibrary("imm32");
        exe.linkSystemLibrary("winmm");
        exe.linkSystemLibrary("version");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("setupapi");

        exe.setTarget(.{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        });
    }

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
