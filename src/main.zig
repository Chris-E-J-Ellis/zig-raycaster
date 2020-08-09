const std = @import("std");
const engine = @import("engine.zig");
const sdl_wrapper = @import("sdl_wrapper.zig");
usingnamespace @import("map.zig");

const SDLRenderer = @import("sdl_renderer.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    const width: usize = 640;
    const height: usize = 400;

    var sdl_renderer = try SDLRenderer.init(width, height, allocator);
    defer sdl_renderer.deinit();
    var renderer = &sdl_renderer.renderer;

    var state = try engine.GameState.initDefault(width, height);

    var time: i128 = 0;
    var old_time: i128 = 0;
    comptime const min_time_per_frame = 16 * std.time.ns_per_ms;

    var ticks: usize = 0xFFFFFF;
    while (ticks > 0) : (ticks -= 1) {
        if (processInput(&state))
            break;
        if (processEvents())
            break;
        engine.tick(&state);
        engine.draw(&state, renderer);

        // Quick and dirty cap at ~60FPs.
        old_time = time;
        time = std.time.nanoTimestamp();
        var delta_time = time - old_time;
        if (delta_time < min_time_per_frame) {
            std.time.sleep(@intCast(u64, min_time_per_frame - delta_time));
        }
        delta_time = std.time.nanoTimestamp() - old_time;

        const frame_time_seconds = @intToFloat(f32, delta_time) / std.time.ns_per_s;
        const fps = @floatToInt(i32, 1 / frame_time_seconds);
        //std.debug.print("FPS:{} Frame Time (s): {d}\n", .{ fps, frame_time_seconds });
    }
}

// Basic movement for testing.
pub fn processInput(state: *engine.GameState) bool {
    var keys = sdl_wrapper.getKeyboardState();

    if (keys.isPressed(.k))
        engine.turnLeft(state);

    if (keys.isPressed(.l))
        engine.turnRight(state);

    if (keys.isPressed(.w))
        engine.moveForward(state);

    if (keys.isPressed(.s))
        engine.moveBackward(state);

    if (keys.isPressed(.a))
        engine.strafeLeft(state);

    if (keys.isPressed(.d))
        engine.strafeRight(state);

    if (keys.isPressed(.i)) {
        std.debug.print("state {}\n", .{state});
    }

    if (keys.isPressed(.x)) {
        return true;
    }

    return false;
}

pub fn processEvents() bool {
    while (sdl_wrapper.pollEvent()) |event| {
        switch (event) {
            (.quit) => return true,
            else => return false,
        }
    }
    return false;
}
