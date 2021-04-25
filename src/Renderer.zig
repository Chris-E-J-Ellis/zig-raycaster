const Renderer = @This();
pub const Colour = struct { r: u8, g: u8, b: u8 };

/// My crack at some kind of interface
drawFloorAndCeilingFn: fn (self: *Renderer) void,
drawCenteredColumnFn: fn (self: *Renderer, x: usize, height: usize, colour: u32) void,
drawCenteredTexturedColumnFn: fn (self: *Renderer, x: usize, height: usize, texels: []const u32) void,
drawRectFn: fn (self: *Renderer, x: usize, y: usize, width: usize, height: usize, colour: Colour) void,
drawLineFn: fn (self: *Renderer, x1: usize, y2: usize, x2: usize, y2: usize, colour: Colour) void,
clearScreenFn: fn (self: *Renderer) void,
refreshScreenFn: fn refreshScreen(self: *Renderer) void,

pub fn refreshScreen(self: *Renderer) void {
    self.refreshScreenFn(self);
}

pub fn clearScreen(self: *Renderer) void {
    self.clearScreenFn(self);
}

pub fn drawFloorAndCeiling(self: *Renderer) void {
    self.drawFloorAndCeilingFn(self);
}

pub fn drawCenteredColumn(self: *Renderer, x: usize, height: usize, colour: u32) void {
    self.drawCenteredColumnFn(self, x, height, colour);
}

pub fn drawCenteredTexturedColumn(self: *Renderer, x: usize, height: usize, texels: []const u32) void {
    self.drawCenteredTexturedColumnFn(self, x, height, texels);
}

pub fn drawRect(self: *Renderer, x: usize, y: usize, width: usize, height: usize, colour: Colour) void {
    self.drawRectFn(self, x, y, width, height, colour);
}

pub fn drawLine(self: *Renderer, x1: usize, y1: usize, x2: usize, y2: usize, colour: Colour) void {
    self.drawLineFn(self, x1, y1, x2, y2, colour);
}
