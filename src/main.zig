const std = @import("std");
const engine = @import("engine.zig");
const sdl_wrapper = @import("sdl_wrapper.zig");
usingnamespace @import("map.zig");

const SDLRenderer = @import("SDLRenderer.zig");

pub fn main() anyerror!void {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gp.deinit();
    var allocator = gp.allocator();

    const width: usize = 320;
    const height: usize = 200;

    var sdl_renderer = try SDLRenderer.init(width, height, &allocator);
    defer sdl_renderer.deinit();
    var renderer = &sdl_renderer.renderer;

    var state = try engine.GameState.initDefault(&allocator, width, height);
    defer state.deinit();

    var time: i128 = 0;
    var old_time: i128 = 0;
    const min_time_per_frame = 16 * std.time.ns_per_ms;

    var ticks: u32 = 0xFFFFFF;
    while (ticks > 0) : (ticks -= 1) {
        if (processInput(&state))
            break;
        if (processEvents(&state))
            break;
        engine.tick(&state);
        engine.draw(&state, renderer);

        // Quick and dirty cap at ~60FPs.
        old_time = time;
        time = std.time.nanoTimestamp();
        var delta_time = time - old_time;
        if (delta_time < min_time_per_frame) {
            std.time.sleep(@intCast(min_time_per_frame - delta_time));
        }
        delta_time = std.time.nanoTimestamp() - old_time;

        //const frame_time_seconds = @intToFloat(f32, delta_time) / std.time.ns_per_s;
        //const fps = @floatToInt(i32, 1 / frame_time_seconds);
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

    if (keys.isPressed(.t)) {
        engine.toggleTextures(state);
    }

    if (keys.isPressed(.m)) {
        engine.toggleMap(state);
    }

    if (keys.isPressed(.g)) {
        engine.toggleMainGame(state);
    }

    if (keys.isPressed(.x)) {
        return true;
    }

    return false;
}

pub fn processEvents(state: *engine.GameState) bool {
    while (sdl_wrapper.pollEvent()) |event| {
        switch (event) {
            .quit => return true,
            .window => switch (event.window) {
                .resize => engine.setScreenSize(state, event.window.resize.width, event.window.resize.height),
                else => return false,
            },
            else => return false,
        }
    }
    return false;
}
