pub const GameState = struct {
    camera_x: u32,
    camera_y: u32,
    viewing_angle: f32,
};

pub const Map = struct {
    width: u8,
    height: u8,
    data: [100]u8 = [_]u8{0} ** (100),

    pub fn populateEdges(self: Map) void {
        var mut_self = self;
        for (mut_self.data) |*item, index| {
            if (index < 10 or index % self.width == 0)
                item.* = 1;
        }
    }
};

pub fn tick(state: *GameState) void {}
