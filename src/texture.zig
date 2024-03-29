const std = @import("std");
const Allocator = std.mem.Allocator;

pub const texture_width = 64;
pub const texture_height = 64;
const texture_data_length = texture_width * texture_height;

const error_texture_path: []const u8 = "data/error.bmp";

const texture_filepaths = [_][]const u8{
    error_texture_path,
    "data/bluestone.bmp",
    "data/wood.bmp",
    "data/eagle.bmp",
    "data/greystone.bmp",
    "data/colorstone.bmp",
    "data/redbrick.bmp",
    "data/mossy.bmp",
    "data/purplestone.bmp",
    "data/purplestone.bmp",
};

pub const Texture = struct {
    allocator: *Allocator,
    width: u32 = texture_width,
    height: u32 = texture_height,
    data: []u32 = undefined,

    pub fn createFromFile(allocator: *Allocator, filename: []const u8) !Texture {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try std.fs.realpath(filename, &path_buffer);

        const file = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
        defer file.close();

        const max_buffer_size = 15 * 1024; // Big enough for my current testing textures
        const file_buffer = try file.readToEndAlloc(allocator.*, max_buffer_size);
        defer allocator.free(file_buffer);

        const data = try allocator.alloc(u32, texture_data_length);
        errdefer allocator.free(data);

        var texture = Texture{
            .allocator = allocator,
            .width = texture_width,
            .height = texture_height,
            .data = data,
        };

        const image_data_start_offset = file_buffer[0x0A];
        for (texture.data, 0..) |*texel, index| {
            const r: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3) + 2]) << 16;
            const g: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3) + 1]) << 8;
            const b: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3)]);
            texel.* = r | g | b;
        }

        // Swap texture x and y for easier slice passing later.
        flipY(texture);
        transposeXY(texture);

        return texture;
    }

    pub fn loadPlaceholderTextures(allocator: *Allocator) ![]Texture {
        const placeholder_texture_count = 9;
        var textures = try allocator.alloc(Texture, placeholder_texture_count);
        for (textures) |*texture| {
            const data = try allocator.alloc(u32, texture_data_length);
            errdefer allocator.free(data);
            texture.* = Texture{
                .allocator = allocator,
                .data = data,
                .width = texture_width,
                .height = texture_height,
            };
        }

        // Generate some textures.
        var x: u32 = 0;
        while (x < texture_width) : (x += 1) {
            var y: u32 = 0;
            while (y < texture_height) : (y += 1) {
                const x_colour: u32 = x * 256 / texture_width;
                const xy_colour: u32 = y * 128 / texture_height + x * 128 / texture_width;
                const xor_colour = (x * 256 / texture_width) ^ (y * 256 / texture_height);
                textures[1].data[x + y * texture_width] = 0xAA0000 * @as(u32, @intFromBool(x != y and x != texture_width - y));
                textures[2].data[x + y * texture_width] = 0x000100 * xor_colour;
                textures[3].data[x + y * texture_width] = 0x000001 * xy_colour;
                textures[4].data[x + y * texture_width] = 0x010100 * @as(u32, @intFromBool(x % 16 != 0 and y % 16 != 0 and y != 63)) * x_colour;
                textures[5].data[x + y * texture_width] = 0x010001 * x_colour;
                textures[6].data[x + y * texture_width] = 0xFFFFFF * @as(u32, @intFromBool(x != 0 and x != 63 and y != 0 and y != 63));

                if (x == 0)
                    textures[6].data[x + y * texture_width] = 0x33FF33;
                if (x == 63)
                    textures[6].data[x + y * texture_width] = 0x33FFFF;
            }
        }

        // Swap texture x and y for easier slice passing later.
        for (textures) |texture| {
            flipY(texture);
            transposeXY(texture);
        }

        return textures;
    }

    // Probably doesn't belong in this struct, should have some kind of loader that cleans up.
    pub fn loadTextures(allocator: *Allocator) ![]Texture {
        var textures = try allocator.alloc(Texture, texture_filepaths.len);

        for (texture_filepaths, 0..) |path, index| {
            textures[index] = createFromFile(allocator, path) catch try createFromFile(allocator, error_texture_path);
        }

        return textures;
    }

    pub fn deinit(self: *Texture) void {
        self.allocator.free(self.data);
        self.data = undefined;
    }

    fn transposeXY(texture: Texture) void {
        var y: u32 = 0;
        while (y < texture.height) : (y += 1) {
            var x: u32 = 0;
            while (x < y) : (x += 1) {
                std.mem.swap(u32, &texture.data[x + y * texture.width], &texture.data[y + x * texture.height]);
            }
        }
    }

    fn flipY(texture: Texture) void {
        var y: u32 = 0;
        while (y < texture.height / 2) : (y += 1) {
            const start_index = y * texture.width;
            const end_index = ((texture_height - 1) * texture_width) - start_index;
            const start_slice = texture.data[start_index .. start_index + texture_width];
            const end_slice = texture.data[end_index .. end_index + texture_width];
            for (0..texture.height) |index| {
                std.mem.swap(u32, &start_slice[index], &end_slice[index]);
            }
        }
    }
};
