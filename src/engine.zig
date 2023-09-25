const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const Texture = @import("texture.zig").Texture;
const Renderer = @import("Renderer.zig");
const Colour = Renderer.Colour;
const Map = @import("map.zig").Map;

// Game drawing
const texture_height = @import("texture.zig").texture_height;
const texture_width = @import("texture.zig").texture_height;
const cell_size = 64;
const speed_scale = 4;
const rads_per_deg: f32 = std.math.tau / 360.0;
const default_fov = 60;

// Map drawing
var map_display_height: u32 = 400;
var map_display_width: u32 = 400;
const colour_white = Colour{ .r = 255, .g = 255, .b = 255 };
const colour_red = Colour{ .r = 255, .g = 25, .b = 25 };
const colour_blue = Colour{ .r = 55, .g = 55, .b = 255 };
const colour_green = Colour{ .r = 55, .g = 255, .b = 55 };
const colour_light_grey = Colour{ .r = 180, .g = 180, .b = 180 };
const colour_default = Colour{ .r = 255, .g = 255, .b = 255 };

pub const GameState = struct {
    allocator: *Allocator,
    screen_width: usize,
    screen_height: usize,
    distance_to_projection_plane: f32,
    player_x: u32,
    player_y: u32,
    player_angle: u32,
    fov: u32,
    map: Map,
    textures: []Texture,
    draw_textures: bool = true,
    draw_map: bool = false,
    draw_main_game: bool = true,

    pub fn initDefault(allocator: *Allocator, width: usize, height: usize) !GameState {
        return GameState{
            .allocator = allocator,
            .player_x = (cell_size * 2),
            .player_y = (cell_size * 2),
            .player_angle = 0,
            .fov = default_fov,
            .map = try Map.createFromFile(allocator, "data/map1.map"),
            //.map = try Map.createEmpty(allocator, 10, 10),
            .screen_width = width,
            .screen_height = height,
            .distance_to_projection_plane = @as(f32, @floatFromInt(width / 2)) / std.math.tan(rads_per_deg * default_fov / 2),
            .textures = try Texture.loadTextures(allocator),
            //.textures = try Texture.loadPlaceholderTextures(allocator),
            .draw_textures = true,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.map.deinit();

        for (self.textures) |*texture| {
            texture.deinit();
        }
        self.allocator.free(self.textures);
        self.textures = undefined;
    }
};

pub fn draw(state: *GameState, renderer: *Renderer) void {
    if (state.draw_main_game) {
        renderer.drawFloorAndCeiling();
        drawWalls(state, renderer);
        renderer.updateBuffer();
    }

    // Draw the map on top of the main game buffer, just a test.
    if (state.draw_map)
        drawMap(state, renderer);

    renderer.refreshScreen();
}

fn drawMap(state: *GameState, renderer: *Renderer) void {

    // Render map as grid, scale based on height (usually the smaller screen dimension).
    const cell_display_size = map_display_height / state.map.height;
    var x: u32 = 0;
    while (x < state.map.width) : (x += 1) {
        var y: u32 = 0;
        while (y < state.map.height) : (y += 1) {
            const index = x + (y * state.map.width);
            if (state.map.data[index] > 0) {
                renderer.drawRect(x * cell_display_size, y * cell_display_size, cell_display_size, cell_display_size, colour_default);
            }
        }
    }

    // Render some fov rays
    const rays_to_cast: f32 = 50;
    const cell_display_scale: f32 = @as(f32, @floatFromInt(map_display_height)) / @as(f32, @floatFromInt(cell_size * state.map.height));
    const player_x_scaled = @as(f32, @floatFromInt(state.player_x)) * cell_display_scale;
    const player_y_scaled = @as(f32, @floatFromInt(state.player_y)) * cell_display_scale;

    const player_angle = @as(f32, @floatFromInt(state.player_angle));
    const column_angle = @as(f32, @floatFromInt(state.fov)) / rays_to_cast;

    const start_angle = player_angle + @as(f32, @floatFromInt(@divFloor(state.fov, 2)));
    var render_angle = wrapAngle(f32, start_angle);

    var ray_cast_count: u32 = 0;
    while (ray_cast_count < rays_to_cast) : (ray_cast_count += 1) {
        const ray_cast_result = castRay(state.map, state.player_x, state.player_y, render_angle);
        const scaled_distance = ray_cast_result.distance * cell_display_scale;
        const ray_colour = if (ray_cast_count == 0 or ray_cast_count == rays_to_cast - 1) colour_red else colour_light_grey;
        const hit_x = player_x_scaled + scaled_distance * std.math.cos(render_angle * rads_per_deg);
        const hit_y = player_y_scaled - scaled_distance * std.math.sin(render_angle * rads_per_deg);

        // Draw ray
        renderer.drawLine(@intFromFloat(player_x_scaled), @intFromFloat(player_y_scaled), @intFromFloat(hit_x), @intFromFloat(hit_y), ray_colour);

        // Highlight map cell
        renderer.drawRect(ray_cast_result.map_x * cell_display_size, ray_cast_result.map_y * cell_display_size, cell_display_size, cell_display_size, colour_red);

        render_angle = wrapAngle(f32, render_angle - column_angle);
    }

    // Draw player direction ray.
    const ray_cast_result = castRay(state.map, state.player_x, state.player_y, player_angle);
    const scaled_distance = ray_cast_result.distance * cell_display_scale;
    const hit_x = player_x_scaled + scaled_distance * std.math.cos(player_angle * rads_per_deg);
    const hit_y = player_y_scaled - scaled_distance * std.math.sin(player_angle * rads_per_deg);
    renderer.drawLine(@intFromFloat(player_x_scaled), @intFromFloat(player_y_scaled), @intFromFloat(hit_x), @intFromFloat(hit_y), colour_green);
}

fn drawWalls(state: *GameState, renderer: *Renderer) void {
    const player_angle = @as(f32, @floatFromInt(state.player_angle));
    const column_angle = @as(f32, @floatFromInt(state.fov)) / @as(f32, @floatFromInt(state.screen_width));

    const start_angle = player_angle + @as(f32, @floatFromInt(@divFloor(state.fov, 2)));
    var render_angle = wrapAngle(f32, start_angle);

    var column_render_count: u32 = 0;
    while (column_render_count < state.screen_width) : (column_render_count += 1) {
        const rayCastResult = castRay(state.map, state.player_x, state.player_y, render_angle);

        const viewing_angle = std.math.fabs(player_angle - render_angle);
        var height = calcHeight(state.distance_to_projection_plane, rayCastResult.distance, viewing_angle);

        if (state.draw_textures) {

            // Draw to screen, could save some effort by precomputing these darkened texels.
            const texture = state.textures[rayCastResult.wall_type];
            const texel_index = rayCastResult.texel_intersect * texture.height;
            const texels = texture.data[texel_index .. texel_index + texture.height];
            var tex_buf: [texture_height]u32 = undefined;
            for (&tex_buf, 0..) |*texel, i| {
                // Darken and remove errant bits if required
                texel.* = if (!rayCastResult.vertical_wall) texels[i] else (texels[i] >> 1) & 0x7F7F7F;
            }

            renderer.drawCenteredTexturedColumn(column_render_count, height, tex_buf[0..]);
        } else {
            const color: u32 = if (rayCastResult.vertical_wall) 0x555555 else 0xAAAAAA;
            renderer.drawCenteredColumn(column_render_count, height, color);
        }

        // Increment angle
        render_angle = wrapAngle(f32, render_angle - column_angle);
    }
}

const RayCastResult = struct {
    map_x: u32,
    map_y: u32,
    distance: f32,
    vertical_wall: bool,
    wall_type: u8,
    texel_intersect: u32,
};

/// Use DDA to cast a ray within a supplied map.
fn castRay(map: Map, start_x: u32, start_y: u32, angle_degs: f32) RayCastResult {
    const start_cell_x = @divFloor(start_x, cell_size);
    const start_cell_y = @divFloor(start_y, cell_size);

    // Find directions
    var y_dir: i2 = if (angle_degs < 180) -1 else 1;
    var x_dir: i2 = if (angle_degs > 90 and angle_degs < 270) -1 else 1;

    // Find DDA step sizes
    // Some cos/sin radian oddities to check out.
    const sin_theta = std.math.cos((90 - angle_degs) * rads_per_deg);
    const cos_theta = std.math.cos(angle_degs * rads_per_deg);
    const delta_dist_x = std.math.fabs(1 / cos_theta);
    const delta_dist_y = std.math.fabs(1 / sin_theta);

    const x_step = delta_dist_x * cell_size;
    const y_step = delta_dist_y * cell_size;

    var x_walk: f32 = if (x_dir == 1)
        @as(f32, @floatFromInt(((start_cell_x + 1) * cell_size) - start_x)) * delta_dist_x
    else
        @as(f32, @floatFromInt(start_x - (start_cell_x * cell_size))) * delta_dist_x;

    var y_walk = if (y_dir == 1)
        @as(f32, @floatFromInt(((start_cell_y + 1) * cell_size) - start_y)) * delta_dist_y
    else
        @as(f32, @floatFromInt(start_y - (start_cell_y * cell_size))) * delta_dist_y;

    var x_walk_cell: i32 = @intCast(start_cell_x);
    var y_walk_cell: i32 = @intCast(start_cell_y);

    var wall_type: u8 = undefined;
    var vertical_wall_hit = false;
    var hit = false;
    while (hit == false) {
        if (x_walk < y_walk) {
            x_walk += x_step;
            x_walk_cell += x_dir;
            vertical_wall_hit = true;
        } else {
            y_walk += y_step;
            y_walk_cell += y_dir;
            vertical_wall_hit = false;
        }

        var index: usize = @intCast(x_walk_cell + (y_walk_cell * @as(i32, @intCast(map.width))));

        if (map.data[index] >= 1) {
            wall_type = map.data[index];
            hit = true;
        }
    }

    // Remove one step's worth of walking for hit distance.
    const distance = if (vertical_wall_hit)
        x_walk - x_step
    else
        y_walk - y_step;

    // Calculate intersection texel.
    const texel_intersect_coord = if (vertical_wall_hit)
        @as(f32, @floatFromInt(start_y)) - (distance * sin_theta)
    else
        (distance * cos_theta) + @as(f32, @floatFromInt(start_x));

    // Flip texture depending on direction.
    var texel_intersect = @as(u32, @intFromFloat(@mod(texel_intersect_coord, cell_size)));
    if ((vertical_wall_hit and x_dir == -1) or (!vertical_wall_hit and y_dir == 1))
        texel_intersect = (texture_width - 1) - texel_intersect;

    return RayCastResult{
        .map_x = @intCast(x_walk_cell),
        .map_y = @intCast(y_walk_cell),
        .distance = distance,
        .vertical_wall = vertical_wall_hit,
        .wall_type = wall_type,
        .texel_intersect = texel_intersect,
    };
}

/// One method of calculating column height, uses component of view angle.
/// I think there's a small curve issue somewhere here, but that's a job for later =D
fn calcHeight(distance_to_projection_plane: f32, distance: f32, viewing_angle: f32) u32 {
    var view_corrected_distance = distance * std.math.cos(viewing_angle * rads_per_deg);

    // Collision detection can remove this check
    if (view_corrected_distance == 0)
        view_corrected_distance += 0.01;

    const col_height = @as(u32, @intFromFloat(cell_size / view_corrected_distance * distance_to_projection_plane));

    return col_height;
}

// Basic movement for testing.
pub fn turnLeft(state: *GameState) void {
    if (state.player_angle >= 359) {
        state.player_angle = 0;
    } else {
        state.player_angle += 1;
    }
}

pub fn turnRight(state: *GameState) void {
    if (state.player_angle <= 0) {
        state.player_angle = 359;
    } else {
        state.player_angle -= 1;
    }
}

// Simple movement, not too fine grained, given how much shared logic there is here, I can tidy this up.
pub fn moveForward(state: *GameState) void {
    var x_inc = std.math.cos(@as(f32, @floatFromInt(state.player_angle)) * rads_per_deg) * speed_scale;
    var y_inc = std.math.sin(@as(f32, @floatFromInt(state.player_angle)) * rads_per_deg) * speed_scale;
    state.player_x = if (x_inc < 0) state.player_x - @as(u32, @intFromFloat(std.math.fabs(x_inc))) else state.player_x + @as(u32, @intFromFloat(x_inc));
    state.player_y = if (y_inc < 0) state.player_y + @as(u32, @intFromFloat(std.math.fabs(y_inc))) else state.player_y - @as(u32, @intFromFloat(y_inc));
}

pub fn moveBackward(state: *GameState) void {
    var x_inc = std.math.cos(@as(f32, @floatFromInt(state.player_angle)) * rads_per_deg) * speed_scale;
    var y_inc = std.math.sin(@as(f32, @floatFromInt(state.player_angle)) * rads_per_deg) * speed_scale;
    state.player_x = if (x_inc < 0) state.player_x + @as(u32, @intFromFloat(std.math.fabs(x_inc))) else state.player_x - @as(u32, @intFromFloat(x_inc));
    state.player_y = if (y_inc < 0) state.player_y - @as(u32, @intFromFloat(std.math.fabs(y_inc))) else state.player_y + @as(u32, @intFromFloat(y_inc));
}

pub fn strafeLeft(state: *GameState) void {
    var x_inc = std.math.cos(@as(f32, @floatFromInt(state.player_angle + 270)) * rads_per_deg) * speed_scale;
    var y_inc = std.math.sin(@as(f32, @floatFromInt(state.player_angle + 270)) * rads_per_deg) * speed_scale;
    state.player_x = if (x_inc < 0) state.player_x + @as(u32, @intFromFloat(std.math.fabs(x_inc))) else state.player_x - @as(u32, @intFromFloat(x_inc));
    state.player_y = if (y_inc < 0) state.player_y - @as(u32, @intFromFloat(std.math.fabs(y_inc))) else state.player_y + @as(u32, @intFromFloat(y_inc));
}

pub fn strafeRight(state: *GameState) void {
    var x_inc = std.math.cos(@as(f32, @floatFromInt(state.player_angle + 90)) * rads_per_deg) * speed_scale;
    var y_inc = std.math.sin(@as(f32, @floatFromInt(state.player_angle + 90)) * rads_per_deg) * speed_scale;
    state.player_x = if (x_inc < 0) state.player_x + @as(u32, @intFromFloat(std.math.fabs(x_inc))) else state.player_x - @as(u32, @intFromFloat(x_inc));
    state.player_y = if (y_inc < 0) state.player_y - @as(u32, @intFromFloat(std.math.fabs(y_inc))) else state.player_y + @as(u32, @intFromFloat(y_inc));
}

pub fn toggleTextures(state: *GameState) void {
    state.draw_textures = !state.draw_textures;
}

pub fn toggleMap(state: *GameState) void {
    state.draw_map = !state.draw_map;
}

pub fn toggleMainGame(state: *GameState) void {
    state.draw_main_game = !state.draw_main_game;
}

pub fn tick(state: *const GameState) void {
    _ = state;
    // Do something.
}

pub fn setScreenSize(state: *const GameState, screen_width: u32, screen_height: u32) void {
    // For now, just scale the map, ensure the size is divisible by the number of map cells.
    map_display_height = screen_height - @mod(screen_height, state.map.height);
    map_display_width = screen_width - @mod(screen_width, state.map.width);
}

fn wrapAngle(comptime T: type, angle: T) T {
    if (angle < 360 and angle >= 0)
        return angle;

    if (angle >= 360) {
        return angle - 360;
    } else {
        return angle + 360;
    }
}

test "DDA - Light texel position testing" {
    const allocator = std.testing.allocator;
    var map = try Map.createEmpty(allocator, 4, 4);
    defer map.deinit();

    const start_x: u32 = (cell_size * 1) + cell_size;
    const start_y: u32 = (cell_size * 1) + cell_size + 0;
    var angle: f32 = 359.0;
    var result = castRay(map, start_x, start_y, angle);

    result = castRay(map, start_x, start_y, angle);
    try testing.expectEqual(result.texel_intersect, 1);

    angle = 0.0;
    result = castRay(map, start_x, start_y, angle);
    try testing.expectEqual(result.texel_intersect, 0);

    angle = 0.8;
    result = castRay(map, start_x, start_y, angle);
    try testing.expectEqual(result.texel_intersect, 63);
}

test "DDA - Scan the wall and check the texture intersect" {
    const allocator = std.testing.allocator;
    var map = try Map.createEmpty(allocator, 4, 4);
    defer map.deinit();

    const start_x: u32 = (cell_size * 1);
    const start_y: u32 = (cell_size * 1);
    const angle: f32 = 0;
    var result = castRay(map, start_x, start_y, angle);
    std.debug.print("\n", .{});

    var current_x = start_x;
    while (current_x < start_x + cell_size) : (current_x += 1) {
        result = castRay(map, current_x, start_y, angle);
        const expected_texel_intersect = @mod(current_x, texture_height);
        try testing.expectEqual(expected_texel_intersect, result.texel_intersect);
    }
}

test "DDA - A bunch of loose direction tests" {
    const allocator = std.testing.allocator;
    var map = try Map.createEmpty(allocator, 10, 10);
    defer map.deinit();

    const start_x: u32 = (cell_size * 5);
    const start_y: u32 = (cell_size * 5);
    var player_angle: f32 = 0.0;

    var result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 9);
    try testing.expect(result.map_y == 4);
    try testing.expect(result.vertical_wall == true);
    try testing.expect(result.distance == 256);

    player_angle = 90;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 5);
    try testing.expect(result.map_y == 0);
    try testing.expect(result.vertical_wall == false);
    try testing.expect(result.distance == 256);

    player_angle = 180;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 0);
    try testing.expect(result.map_y == 5);
    try testing.expect(result.vertical_wall == true);
    try testing.expect(result.distance == 256);

    player_angle = 270;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 5);
    try testing.expect(result.map_y == 9);
    try testing.expect(result.vertical_wall == false);
    try testing.expect(result.distance == 256);

    player_angle = 45;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 8);
    try testing.expect(result.map_y == 0);
    try testing.expect(result.vertical_wall == false);
    try testing.expect(@floor(result.distance) == 362);

    player_angle = 135;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 1);
    try testing.expect(result.map_y == 0);
    try testing.expect(result.vertical_wall == false);
    try testing.expect(@floor(result.distance) == 362);

    player_angle = 225;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 0);
    try testing.expect(result.map_y == 8);
    try testing.expect(result.vertical_wall == true);
    try testing.expect(@floor(result.distance) == 362);

    player_angle = 315;
    result = castRay(map, start_x, start_y, player_angle);

    try testing.expect(result.map_x == 8);
    try testing.expect(result.map_y == 9);
    try testing.expect(result.vertical_wall == false);
    try testing.expect(@floor(result.distance) == 362);
}

test "Angle greater than 360 can be wrapped" {
    var wrapped_angle = wrapAngle(f32, 360);
    try testing.expect(wrapped_angle == 0);
}

test "Angle less than 0 can be wrapped" {
    var wrapped_angle = wrapAngle(f32, -1);
    try testing.expect(wrapped_angle == 359);
}
