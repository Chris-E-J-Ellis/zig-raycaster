const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");

const Renderer = @import("renderer.zig");
const default_screen_height = 640;
const default_screen_width = 400;

var floor_and_ceiling_buffer: []u32 = undefined;
var back_buffer: []u32 = undefined;
var screen: *sdl_wrapper.Window = undefined;
var surface: *sdl_wrapper.Surface = undefined;
var texture: *sdl_wrapper.Texture = undefined;
var renderer: *sdl_wrapper.Renderer = undefined;
var screen_width: usize = undefined;
var screen_height: usize = undefined;

// Follow a similar pattern to the Allocators, I guess this filename should be 'SDLRenderer.zig'
pub const SDLRenderer = @This();

renderer: Renderer,

pub fn init(width: usize, height: usize, allocator: *std.mem.Allocator) !SDLRenderer {
    screen_width = width;
    screen_height = height;
    back_buffer = try allocator.alloc(u32, (screen_width * screen_height));
    floor_and_ceiling_buffer = try allocator.alloc(u32, (screen_width * screen_height));

    try sdl_wrapper.initVideo();
    screen = try sdl_wrapper.createWindow(default_screen_height, default_screen_width);
    renderer = try sdl_wrapper.createRendererFromWindow(screen);
    surface = try sdl_wrapper.createRGBSurface(width, height);
    texture = try sdl_wrapper.createTextureFromSurface(renderer, surface);

    initialiseFloorAndSkyBuffer(width, height);

    return SDLRenderer{
        .renderer = Renderer{
            .drawFloorAndCeilingFn = drawFloorAndCeiling,
            .drawCenteredColumnFn = drawCenteredColumn,
            .drawCenteredTexturedColumnFn = drawCenteredTexturedColumn,
            .refreshScreenFn = refreshScreen,
        },
    };
}

pub fn deinit(self: *SDLRenderer, allocator: *std.mem.Allocator) void {
    allocator.free(back_buffer);
    allocator.free(floor_and_ceiling_buffer);
    sdl_wrapper.destroyTexture(texture);
    sdl_wrapper.freeSurface(surface);
    sdl_wrapper.destroyRenderer(renderer);
    sdl_wrapper.destroyWindow(screen);
    sdl_wrapper.quit();
}

fn refreshScreen(self: *Renderer) void {
    sdl_wrapper.refreshScreenWithBuffer(renderer, texture, back_buffer, screen_width);
}

fn initialiseFloorAndSkyBuffer(width: usize, height: usize) void {
    const light_grey = 0x777777;
    const dark_grey = 0x333333;
    const halfway_index = height / 2;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const index = (y * width) + x;
            floor_and_ceiling_buffer[index] = if (y > halfway_index)
                light_grey
            else
                dark_grey;
        }
    }
}

fn drawFloorAndCeiling(self: *Renderer) void {
    for (floor_and_ceiling_buffer[0..floor_and_ceiling_buffer.len]) |i, dest| {
        back_buffer[dest] = i;
    }
}

fn drawCenteredColumn(self: *Renderer, x: usize, height: usize, colour: u32) void {
    const draw_height = if (height < screen_height) height else screen_height;
    const draw_y_start = if (height < screen_height) @as(usize, @divFloor(screen_height - height, 2)) else 0;

    var draw_y: usize = 0;
    while (draw_y < draw_height) : (draw_y += 1) {
        back_buffer[x + (draw_y + draw_y_start) * screen_width] = colour;
    }
}

fn drawCenteredTexturedColumn(self: *Renderer, x: usize, height: usize, texels: []const u32) void {
    var texel_start_offset: f32 = 0;
    var back_buffer_offset: f32 = 0;
    var draw_height = height;

    if (height > screen_height) {
        draw_height = screen_height;
        texel_start_offset = @intToFloat(f32, height - screen_height) / 2;
    } else {
        back_buffer_offset = @intToFloat(f32, screen_height - height) / 2;

        // A dirty hack to make texures look nicer, likely needs a dive into distance calc/floats.
        if (height % 2 != 0) {
            texel_start_offset += 0.5;
            back_buffer_offset += 0.5;
        }
    }

    var draw_y: usize = 0;
    while (draw_y < draw_height) : (draw_y += 1) {
        const texel_index = ((@intToFloat(f32, draw_y) + texel_start_offset) * @intToFloat(f32, texels.len)) / @intToFloat(f32, height);
        var texel = texels[@floatToInt(usize, texel_index)];

        back_buffer[x + ((draw_y + @floatToInt(usize, back_buffer_offset)) * screen_width)] = texel;
    }
}

fn drawCenteredTexturedColumnAlt(self: *Renderer, x: usize, height: usize, texels: []const u32) void {
    const height_adjust = if (@mod(height, 2) == 0) height else height + 1;
    const draw_start = if (height_adjust < screen_height) (screen_height - height_adjust) / 2 else 0;
    const draw_end = if (height_adjust < screen_height) screen_height - (screen_height - height_adjust) / 2 else screen_height;
    const texel_scale = @intToFloat(f32, texels.len) / @intToFloat(f32, height_adjust);
    const texel_start_offset = if (height_adjust > screen_height) @intToFloat(f32, height_adjust - screen_height) / 2 else 0;
    var texel_index = texel_start_offset * texel_scale;

    var count: usize = 0;
    var draw_y = draw_start;
    while (draw_y < draw_end) : ({
        draw_y += 1;
        texel_index += texel_scale;
    }) {
        const texel = texels[@floatToInt(usize, texel_index)];
        back_buffer[x + draw_y * screen_width] = texel;
    }
}
