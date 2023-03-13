const Renderer = @This();

pub const Colour = struct { r: u8, g: u8, b: u8 };

/// My crack at some kind of interface, just to get more familiar with the language.
drawFloorAndCeilingFn: *const fn (self: *Renderer) void,
drawCenteredColumnFn: *const fn (self: *Renderer, x: u32, height: u32, colour: u32) void,
drawCenteredTexturedColumnFn: *const fn (self: *Renderer, x: u32, height: u32, texels: []const u32) void,
drawRectFn: *const fn (self: *Renderer, x: u32, y: u32, width: u32, height: u32, colour: Colour) void,
drawLineFn: *const fn (self: *Renderer, x: u32, y: u32, x: u32, y: u32, colour: Colour) void,
updateBufferFn: *const fn (self: *Renderer) void,
refreshScreenFn: *const fn (self: *Renderer) void,

pub fn refreshScreen(self: *Renderer) void {
    self.refreshScreenFn(self);
}

pub fn updateBuffer(self: *Renderer) void {
    self.updateBufferFn(self);
}

pub fn drawFloorAndCeiling(self: *Renderer) void {
    self.drawFloorAndCeilingFn(self);
}

pub fn drawCenteredColumn(self: *Renderer, x: u32, height: u32, colour: u32) void {
    self.drawCenteredColumnFn(self, x, height, colour);
}

pub fn drawCenteredTexturedColumn(self: *Renderer, x: u32, height: u32, texels: []const u32) void {
    self.drawCenteredTexturedColumnFn(self, x, height, texels);
}

pub fn drawRect(self: *Renderer, x: u32, y: u32, width: u32, height: u32, colour: Colour) void {
    self.drawRectFn(self, x, y, width, height, colour);
}

pub fn drawLine(self: *Renderer, x1: u32, y1: u32, x2: u32, y2: u32, colour: Colour) void {
    self.drawLineFn(self, x1, y1, x2, y2, colour);
}
