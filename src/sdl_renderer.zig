const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");

const Renderer = @import("renderer.zig");

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
    screen = try sdl_wrapper.createWindow(width, height);
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

pub fn deinit(self: *SDLRenderer) void {
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
    var draw_y: usize = 0;
    var draw_y_start = @as(usize, @divFloor(screen_height - height, 2));

    while (draw_y < height) : (draw_y += 1) {
        back_buffer[x + (draw_y + draw_y_start) * screen_width] = colour;
    }
}

fn drawCenteredTexturedColumn(self: *Renderer, x: usize, height: usize, texels: []const u32) void {
    const draw_height = if (height > screen_height) screen_height else height;
    const texel_start_offset = if (height > screen_height) @divFloor(height - screen_height, 2) else 0;
    const back_buffer_offset = if (height < screen_height) @divFloor(screen_height - height, 2) else 0;

    var draw_y: usize = 0;
    while (draw_y < draw_height) : (draw_y += 1) {
        const texel_index = ((draw_y + texel_start_offset) * texels.len) / height;
        const texel = texels[texel_index];
        back_buffer[x + ((draw_y + back_buffer_offset) * screen_width)] = texel;
    }

    drawCenteredTexturedColumnAlt(self, x, height, texels);
}

fn drawCenteredTexturedColumnAlt(self: *Renderer, x: usize, height: usize, texels: []const u32) void {
    const draw_start = if (height < screen_height) @divFloor(screen_height - height, 2) else 0;
    const draw_end = if (height < screen_height) screen_height - @divFloor(screen_height - height, 2) else screen_height;
    const texel_start_offset = if (height > screen_height) @divFloor(height - screen_height, 2) else 0;
    var texel_index = (texel_start_offset * texels.len) / height;

    var count: usize = 0;
    var draw_y = draw_start;
    while (draw_y < draw_end) : ({
        draw_y += 1;
        count += 1;
    }) {
        const texel = texels[texel_index];
        back_buffer[x + draw_y * screen_width] = texel;
        texel_index = (texel_start_offset + count) * texels.len / height;
    }
}
