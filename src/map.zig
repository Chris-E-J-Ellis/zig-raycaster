const std = @import("std");
const testing = std.testing;

// Not really interested in big maps or allocation for the moment.
pub const Map = struct {
    width: u32,
    height: u32,
    data: [1000]u8,

    pub fn createEmpty(width: u32, height: u32) Map {
        var map = Map{
            .width = width,
            .height = height,
            .data = [_]u8{0} ** 1000,
        };
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
    pub fn createFromFile(filename: []const u8) !Map {
        var pathBuffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try std.fs.realpath(filename, &pathBuffer);

        var fileBuffer: [2000]u8 = undefined;
        const file = try std.fs.openFileAbsolute(file_path, .{ .read = true });
        defer file.close();

        const length = try file.readAll(&fileBuffer);
        var it = std.mem.split(fileBuffer[0..length], "\n");
        const widthLine = it.next().?;
        const heightLine = it.next().?;
        const widthToken = std.mem.tokenize(widthLine, "width =").next().?;
        const heightToken = std.mem.tokenize(heightLine, "height =").next().?;
        const radix = 10;
        const width = try std.fmt.parseInt(u32, widthToken, radix);
        const height = try std.fmt.parseInt(u32, heightToken, radix);

        var mapBuffer: [1000]u8 = [_]u8{0} ** 1000;
        const dataBytes = it.rest();
        var dataCount: usize = 0;
        for (dataBytes) |byte, index| {
            if (!std.ascii.isDigit(byte))
                continue;

            mapBuffer[dataCount] = try std.fmt.parseInt(u8, &[_]u8{byte}, radix);
            dataCount += 1;
        }

        var map = Map{
            .width = width,
            .height = height,
            .data = mapBuffer,
        };

        populateEdges(&map);

        return map;
    }

    pub fn populateEdges(map: *Map) void {
        for (map.data) |*item, index| {
            if (index < map.width or index % map.width == 0 or index % map.width == map.width - 1 or index > (map.width * map.height - map.width)) {
                item.* = 1;
            }
        }
    }
};

test "Try loading a map" {
    const map = try Map.createFromFile("data/map1.map");
    testing.expectEqual(@as(u32, 20), map.width);
    testing.expectEqual(@as(u32, 20), map.height);
}
