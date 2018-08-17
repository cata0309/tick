const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Get options
    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;

    // Environment
    b.addCIncludePath("deps");
    b.addCIncludePath("include");

    // C Dependencies
    var glad = b.addCObject("glad", "deps/glad/glad.c");

    //
    // Game lib
    //
    const version = b.version(0, 0, 1);
    var game_lib = b.addSharedLibrary("game", "games/live.zig", version);
    game_lib.addPackagePath("lib", "lib/index.zig");

    if (windows) {
        game_lib.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Environ.gnu);
    }

    //
    // Dynamically Linked, Hot Reloading
    //
    var dev_exe = b.addExecutable("dev", "platform/dev.zig");
    dev_exe.addPackagePath("lib", "lib/index.zig");
    dev_exe.addObject(glad);

    dev_exe.setBuildMode(mode);
    if (windows) {
        dev_exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Environ.gnu);
    }

    dev_exe.linkSystemLibrary("c");
    dev_exe.linkSystemLibrary("m");
    dev_exe.linkSystemLibrary("z");
    dev_exe.linkSystemLibrary("dl");
    dev_exe.linkSystemLibrary("glfw");
    dev_exe.linkSystemLibrary("png");
    dev_exe.linkSystemLibrary("soundio");
    b.installArtifact(dev_exe);

    const dev_command = b.addCommand(".", b.env_map, [][]const u8{dev_exe.getOutputPath()});
    dev_command.step.dependOn(&glad.step);
    dev_command.step.dependOn(&dev_exe.step);
    dev_command.step.dependOn(&game_lib.step);

    //
    // Statically Linked Executable
    //
    var dist_exe = b.addExecutable("dist", "platform/run.zig");
    dist_exe.addPackagePath("lib", "lib/index.zig");
    dist_exe.addObject(glad);

    dist_exe.setBuildMode(mode);
    if (windows) {
        dist_exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Environ.gnu);
    }

    dist_exe.linkSystemLibrary("c");
    dist_exe.linkSystemLibrary("m");
    dist_exe.linkSystemLibrary("z");
    dist_exe.linkSystemLibrary("dl");
    dist_exe.linkSystemLibrary("glfw");
    dist_exe.linkSystemLibrary("png");
    dist_exe.linkSystemLibrary("soundio");
    b.installArtifact(dist_exe);

    const dist_command = b.addCommand(".", b.env_map, [][]const u8{dist_exe.getOutputPath()});
    dist_command.step.dependOn(&glad.step);
    dist_command.step.dependOn(&dist_exe.step);


    //
    // Commands
    //

    b.default_step.dependOn(&glad.step);
    b.default_step.dependOn(&game_lib.step);
    b.default_step.dependOn(&dev_exe.step);
    b.default_step.dependOn(&dist_exe.step);
 
    const run = b.step("run", "Play the game");
    run.dependOn(&dist_command.step);
    
    const dev = b.step("dev", "Run live development environment");
    dev.dependOn(&dev_command.step);

    const update = b.step("update", "Update game library");
    update.dependOn(&game_lib.step);    
}
