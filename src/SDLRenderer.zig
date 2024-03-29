const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Allocator = std.mem.Allocator;
const Renderer = @import("Renderer.zig");
const Colour = Renderer.Colour;

const default_screen_height = 640;
const default_screen_width = 400;

pub const SDLRenderer = @This();

allocator: *Allocator,
renderer: Renderer,
floor_and_ceiling_buffer: []u32,
back_buffer: []u32,
sdl_screen: *sdl_wrapper.Window,
sdl_surface: *sdl_wrapper.Surface,
sdl_texture: *sdl_wrapper.Texture,
sdl_renderer: *sdl_wrapper.Renderer,
screen_width: u32 = default_screen_height,
screen_height: u32 = default_screen_width,

pub fn init(width: u32, height: u32, allocator: *Allocator) !SDLRenderer {
    const back_buffer = try allocator.alloc(u32, (width * height));
    errdefer allocator.free(back_buffer);

    const floor_and_ceiling_buffer = try allocator.alloc(u32, (width * height));
    errdefer allocator.free(floor_and_ceiling_buffer);
    initialiseFloorAndCeilingBuffer(width, height, floor_and_ceiling_buffer);

    try sdl_wrapper.initVideo();

    const sdl_screen = try sdl_wrapper.createWindow(default_screen_height, default_screen_width);
    errdefer sdl_wrapper.destroyWindow(sdl_screen);

    const sdl_renderer = try sdl_wrapper.createRendererFromWindow(sdl_screen);
    errdefer sdl_wrapper.destroyRenderer(sdl_renderer);

    const sdl_surface = try sdl_wrapper.createRGBSurface(width, height);
    errdefer sdl_wrapper.freeSurface(sdl_surface);

    const sdl_texture = try sdl_wrapper.createTextureFromSurface(sdl_renderer, sdl_surface);
    errdefer sdl_wrapper.destroyTexture(sdl_texture);

    return SDLRenderer{
        .allocator = allocator,
        .back_buffer = back_buffer,
        .floor_and_ceiling_buffer = floor_and_ceiling_buffer,
        .screen_width = width,
        .screen_height = height,
        .sdl_screen = sdl_screen,
        .sdl_renderer = sdl_renderer,
        .sdl_surface = sdl_surface,
        .sdl_texture = sdl_texture,
        .renderer = Renderer{
            .drawFloorAndCeilingFn = drawFloorAndCeiling,
            .drawCenteredColumnFn = drawCenteredColumn,
            .drawCenteredTexturedColumnFn = drawCenteredTexturedColumn,
            .drawRectFn = drawRect,
            .drawLineFn = drawLine,
            .refreshScreenFn = refreshScreen,
            .updateBufferFn = updateBuffer,
        },
    };
}

pub fn deinit(self: *SDLRenderer) void {
    self.allocator.free(self.back_buffer);
    self.back_buffer = undefined;

    self.allocator.free(self.floor_and_ceiling_buffer);
    self.floor_and_ceiling_buffer = undefined;

    sdl_wrapper.destroyTexture(self.sdl_texture);
    sdl_wrapper.freeSurface(self.sdl_surface);
    sdl_wrapper.destroyRenderer(self.sdl_renderer);
    sdl_wrapper.destroyWindow(self.sdl_screen);
    sdl_wrapper.quit();
}

fn updateBuffer(renderer: *Renderer) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer); // Not sure what the overhead is here, just testing "interfaces" =D
    sdl_wrapper.renderBuffer(self.sdl_renderer, self.sdl_texture, self.back_buffer, self.screen_width);
}

fn refreshScreen(renderer: *Renderer) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    sdl_wrapper.refreshScreen(self.sdl_renderer);
}

fn initialiseFloorAndCeilingBuffer(width: u32, height: u32, buffer: []u32) void {
    const light_grey = 0x777777;
    const dark_grey = 0x333333;
    const halfway_index = height / 2;

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const index = (y * width) + x;
            buffer[index] = if (y > halfway_index)
                light_grey
            else
                dark_grey;
        }
    }
}

fn drawFloorAndCeiling(renderer: *Renderer) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    std.mem.copy(u32, self.back_buffer, self.floor_and_ceiling_buffer);
}

fn drawCenteredColumn(renderer: *Renderer, x: u32, height: u32, colour: u32) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    const draw_height = if (height < self.screen_height) height else self.screen_height;
    const draw_y_start = if (height < self.screen_height) @as(usize, @divFloor(self.screen_height - height, 2)) else 0;

    var draw_y: usize = 0;
    while (draw_y < draw_height) : (draw_y += 1) {
        self.back_buffer[x + (draw_y + draw_y_start) * self.screen_width] = colour;
    }
}

fn drawCenteredTexturedColumn(renderer: *Renderer, x: u32, height: u32, texels: []const u32) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    var texel_start_offset: f32 = 0;
    var back_buffer_offset: f32 = 0;
    var draw_height = height;

    if (height > self.screen_height) {
        draw_height = self.screen_height;
        texel_start_offset = @as(f32, @floatFromInt(height - self.screen_height)) / 2;
    } else {
        back_buffer_offset = @as(f32, @floatFromInt(self.screen_height - height)) / 2;

        // A dirty hack to make texures look nicer, likely needs a dive into distance calc/floats.
        if (height % 2 != 0) {
            texel_start_offset += 0.5;
            back_buffer_offset += 0.5;
        }
    }

    var draw_y: usize = 0;
    while (draw_y < draw_height) : (draw_y += 1) {
        const texel_index = ((@as(f32, @floatFromInt(draw_y)) + texel_start_offset) * @as(f32, @floatFromInt(texels.len))) / @as(f32, @floatFromInt(height));
        var texel = texels[@intFromFloat(texel_index)];

        self.back_buffer[x + ((draw_y + @as(usize, @intFromFloat(back_buffer_offset))) * self.screen_width)] = texel;
    }
}

fn drawCenteredTexturedColumnAlt(renderer: *Renderer, x: u32, height: u32, texels: []const u32) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    const height_adjust = if (@mod(height, 2) == 0) height else height + 1;
    const draw_start = if (height_adjust < self.screen_height) (self.screen_height - height_adjust) / 2 else 0;
    const draw_end = if (height_adjust < self.screen_height) self.screen_height - (self.screen_height - height_adjust) / 2 else self.screen_height;
    const texel_scale = @as(f32, @floatFromInt(texels.len)) / @as(f32, @floatFromInt(height_adjust));
    const texel_start_offset = if (height_adjust > self.screen_height) @as(f32, @floatFromInt(height_adjust - self.screen_height)) / 2 else 0;
    var texel_index = texel_start_offset * texel_scale;

    var draw_y = draw_start;
    while (draw_y < draw_end) : ({
        draw_y += 1;
        texel_index += texel_scale;
    }) {
        const texel = texels[@intFromFloat(texel_index)];
        self.back_buffer[x + draw_y * self.screen_width] = texel;
    }
}

pub fn drawRect(renderer: *Renderer, x: u32, y: u32, width: u32, height: u32, colour: Colour) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    const sdl_color = sdl_wrapper.Color{ .r = colour.r, .g = colour.g, .b = colour.b, .a = 255 };
    sdl_wrapper.drawRect(self.sdl_renderer, x, y, width, height, sdl_color);
}

pub fn drawLine(renderer: *Renderer, x1: u32, y1: u32, x2: u32, y2: u32, colour: Colour) void {
    const self = @fieldParentPtr(SDLRenderer, "renderer", renderer);
    const sdl_color = sdl_wrapper.Color{ .r = colour.r, .g = colour.g, .b = colour.b, .a = 255 };
    sdl_wrapper.drawLine(self.sdl_renderer, x1, y1, x2, y2, sdl_color);
}
