const std = @import("std");
const Allocator = std.mem.Allocator;

pub const texture_width = 64;
pub const texture_height = 64;
const texture_data_length = texture_width * texture_height;
const texture_count = 10;

pub const Texture = struct {
    allocator: *Allocator,
    width: u32 = texture_width,
    height: u32 = texture_height,
    data: []u32 = undefined,

    pub fn createFromFile(allocator: *Allocator, filename: []const u8) !Texture {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try std.fs.realpath(filename, &path_buffer);

        const file = try std.fs.openFileAbsolute(file_path, .{ .read = true });
        defer file.close();

        const max_buffer_size = 15 * 1024; // Big enough for my current testing textures
        const file_buffer = try file.readToEndAlloc(allocator, max_buffer_size);
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
        for (texture.data) |*texel, index| {
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
        var textures = try allocator.alloc(Texture, texture_count);
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
                textures[1].data[x + y * texture_width] = 0xAA0000 * @as(u32, @boolToInt(x != y and x != texture_width - y));
                textures[2].data[x + y * texture_width] = 0x000100 * xor_colour;
                textures[3].data[x + y * texture_width] = 0x000001 * xy_colour;
                textures[4].data[x + y * texture_width] = 0x010100 * @as(u32, @boolToInt(x % 16 != 0 and y % 16 != 0 and y != 63)) * x_colour;
                textures[5].data[x + y * texture_width] = 0x010001 * x_colour;
                textures[6].data[x + y * texture_width] = 0xFFFFFF * @as(u32, @boolToInt(x != 0 and x != 63 and y != 0 and y != 63));
                textures[2].data[x + y * texture_width] = 0x000100 * xor_colour;

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

    pub fn loadTextures(allocator: *Allocator) ![]Texture {
        var textures = try allocator.alloc(Texture, texture_count);

        const error_texture = try createFromFile(allocator, "data/error.bmp");
        textures[0] = error_texture;
        textures[1] = createFromFile(allocator, "data/bluestone.bmp") catch error_texture;
        textures[2] = createFromFile(allocator, "data/wood.bmp") catch error_texture;
        textures[3] = createFromFile(allocator, "data/eagle.bmp") catch error_texture;
        textures[4] = createFromFile(allocator, "data/greystone.bmp") catch error_texture;
        textures[5] = createFromFile(allocator, "data/colorstone.bmp") catch error_texture;
        textures[6] = createFromFile(allocator, "data/redbrick.bmp") catch error_texture;
        textures[7] = createFromFile(allocator, "data/mossy.bmp") catch error_texture;
        textures[8] = createFromFile(allocator, "data/purplestone.bmp") catch error_texture;
        textures[9] = createFromFile(allocator, "data/purplestone.bmp") catch error_texture;

        return textures;
    }

    pub fn deinit(self: Texture) void {
        self.allocator.free(self.data);
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
            for (start_slice) |_, index| {
                std.mem.swap(u32, &start_slice[index], &end_slice[index]);
            }
        }
    }
};
