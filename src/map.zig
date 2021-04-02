const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const Map = struct {
    allocator: *Allocator, // This should probably go in some kind of Map manager, but I'm only using one map =D
    width: u32,
    height: u32,
    data: []u8,

    pub fn createEmpty(allocator: *Allocator, width: u32, height: u32) !Map {
        var map = Map{
            .allocator = allocator,
            .width = width,
            .height = height,
            .data = try allocator.alloc(u8, width * height),
        };
        for (map.data) |*byte|
            byte.* = 0x00;
        map.populateEdges();
        return map;
    }

    /// Load a map that looks something like:
    /// ```
    /// width = 3
    /// height = 3
    /// data = [
    ///     1, 1, 1
    ///     1, 0, 1
    ///     1, 1, 1
    /// ]
    /// ```
    pub fn createFromFile(allocator: *Allocator, filename: []const u8) !Map {
        var pathBuffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try std.fs.realpath(filename, &pathBuffer);

        const file = try std.fs.openFileAbsolute(file_path, .{ .read = true });
        defer file.close();

        const max_buffer_size = 2000;
        const file_buffer = try file.readToEndAlloc(allocator, max_buffer_size);
        defer allocator.free(file_buffer);

        var it = std.mem.split(file_buffer, "\n");
        const widthLine = it.next().?;
        const heightLine = it.next().?;
        const widthToken = std.mem.tokenize(widthLine, "width =").next().?;
        const heightToken = std.mem.tokenize(heightLine, "height =").next().?;
        const radix = 10;
        const width = try std.fmt.parseInt(u32, widthToken, radix);
        const height = try std.fmt.parseInt(u32, heightToken, radix);

        var mapDataSize: usize = width * height;
        var mapBuffer = try allocator.alloc(u8, mapDataSize);
        errdefer allocator.free(mapBuffer);

        const dataBytes = it.rest();
        var dataCount: usize = 0;
        for (dataBytes) |byte, index| {
            if (!std.ascii.isDigit(byte))
                continue;

            mapBuffer[dataCount] = try std.fmt.parseInt(u8, &[_]u8{byte}, radix);
            dataCount += 1;
        }

        var map = Map{
            .allocator = allocator,
            .width = width,
            .height = height,
            .data = mapBuffer,
        };

        populateEdges(&map);

        return map;
    }

    pub fn populateEdges(self: *Map) void {
        for (self.data) |*item, index| {
            if (index < self.width or index % self.width == 0 or index % self.width == self.width - 1 or index > (self.width * self.height - self.width)) {
                item.* = 1;
            }
        }
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.data);
    }
};

test "Try loading a map" {
    var allocator = std.testing.allocator;
    var map = try Map.createFromFile(allocator, "data/map1.map");
    defer map.deinit();
    testing.expectEqual(@as(u32, 20), map.width);
    testing.expectEqual(@as(u32, 20), map.height);
    testing.expectEqual(@as(usize, 400), map.data.len);
}
