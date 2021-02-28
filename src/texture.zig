const std = @import("std");

pub const texture_width = 64;
pub const texture_height = 64;
const texture_data_length = texture_width * texture_height;

pub const Texture = struct {
    width: u32 = texture_width,
    height: u32 = texture_height,
    data: [texture_data_length]u32 = [_]u32{0} ** texture_data_length,

    pub fn createFromFile(filename: []const u8) !Texture {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try std.fs.realpath(filename, &path_buffer);

        var file_buffer: [15 * 1024]u8 = undefined;
        const file = try std.fs.openFileAbsolute(file_path, .{ .read = true });
        defer file.close();

        const length = try file.readAll(&file_buffer);

        var texture = Texture{
            .width = 64,
            .height = 64,
        };

        const image_data_start_offset = file_buffer[0x0A];
        for (texture.data) |*texel, index| {
            const r: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3) + 2]) << 16;
            const g: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3) + 1]) << 8;
            const b: u32 = @as(u32, file_buffer[image_data_start_offset + (index * 3)]);
            texel.* = r | g | b;
        }
        return texture;
    }

    pub fn loadDummyTextures() ![10]Texture {
        var textures = [_]Texture{Texture{}} ** 10;

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

                if (x == 0)
                    textures[6].data[x + y * texture_width] = 0x33FF33;
                if (x == 63)
                    textures[6].data[x + y * texture_width] = 0x33FFFF;
            }
        }

        // Swap texture x and y for easier slice passing later.
        for (textures) |texture, index| {
            textures[index] = createWithFlippedXY(texture);
        }

        return textures;
    }

    pub fn loadTextures() ![10]Texture {
        var textures = [_]Texture{Texture{}} ** 10;

        textures[1] = try createFromFile("data/bluestone.bmp");
        textures[2] = try createFromFile("data/wood.bmp");
        textures[3] = try createFromFile("data/eagle.bmp");
        textures[4] = try createFromFile("data/greystone.bmp");
        textures[5] = try createFromFile("data/colorstone.bmp");
        textures[6] = try createFromFile("data/redbrick.bmp");
        textures[7] = try createFromFile("data/mossy.bmp");
        textures[8] = try createFromFile("data/purplestone.bmp");

        // Swap texture x and y and invert bitmap for easier slice passing later.
        for (textures) |texture, index| {
            textures[index] = createWithFlippedY(texture);
            textures[index] = createWithFlippedXY(textures[index]);
        }

        return textures;
    }

    fn createWithFlippedXY(texture: Texture) Texture {
        var flippedTexture = Texture{ .width = texture.width, .height = texture.height };

        var x: u32 = 0;
        while (x < texture.width) : (x += 1) {
            var y: u32 = 0;
            while (y < texture.height) : (y += 1) {
                flippedTexture.data[x + y * texture_width] = texture.data[y + x * texture_height];
            }
        }
        return flippedTexture;
    }

    fn createWithFlippedY(texture: Texture) Texture {
        var flippedTexture = Texture{ .width = texture.width, .height = texture.height };

        var y: u32 = 0;
        while (y < texture.height) : (y += 1) {
            var x: u32 = 0;
            while (x < texture.width) : (x += 1) {
                flippedTexture.data[x + y * texture_width] = texture.data[x + ((texture_height - 1) - y) * texture_width];
            }
        }
        return flippedTexture;
    }
};
