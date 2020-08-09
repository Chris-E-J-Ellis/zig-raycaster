const Renderer = @This();

/// My crack at some kind of interface
drawFloorAndCeilingFn: fn (self: *Renderer) void,
drawCenteredColumnFn: fn (self: *Renderer, x: usize, height: usize, colour: u32) void,
refreshScreenFn: fn refreshScreen(self: *Renderer) void,

pub fn refreshScreen(self: *Renderer) void {
    self.refreshScreenFn(self);
}

pub fn drawFloorAndCeiling(self: *Renderer) void {
    self.drawFloorAndCeilingFn(self);
}

pub fn drawCenteredColumn(self: *Renderer, x: usize, height: usize, colour: u32) void {
    self.drawCenteredColumnFn(self, x, height, colour);
}
