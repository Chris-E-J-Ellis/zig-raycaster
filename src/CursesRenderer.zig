const std = @import("std");
const curses = @cImport({
    @cInclude("ncursesw/ncurses.h");
});
const Allocator = std.mem.Allocator;
const Renderer = @import("Renderer.zig");
const Colour = Renderer.Colour;

pub const CursesRenderer = @This();

allocator: *Allocator,
renderer: Renderer,
screen_width: u32 = default_screen_height,
screen_height: u32 = default_screen_width,

pub fn init(width: u32, height: u32, allocator: *Allocator) !CursesRenderer {
    _ = curses.initscr();
    _ = curses.start_color();
    _ = curses.cbreak();
    _ = curses.noecho();
    _ = curses.curs_set(0);

    _ = curses.printw("Test Palette:\n");
    var i: c_short = 0;
    while (i < 256) : (i += 1) {
        _ = curses.init_pair(i, curses.COLOR_BLACK, i);
        _ = curses.attron(curses.COLOR_PAIR(i));
        _ = curses.printw("%i ", i);
        _ = curses.attroff(curses.COLOR_PAIR(i));
    }

    _ = curses.refresh();

    std.time.sleep(1_000_000_000);

    _ = curses.clear();

    return CursesRenderer{
        .allocator = allocator,
        .screen_width = width,
        .screen_height = height,
        .renderer = Renderer{
            .drawFloorAndCeilingFn = drawFloorAndCeiling,
            .drawCenteredColumnFn = drawCenteredColumn,
            .drawCenteredTexturedColumnFn = drawCenteredTexturedColumn,
            .drawRectFn = drawRect,
            .drawLineFn = drawLine,
            .refreshScreenFn = refreshScreen,
            .updateBufferFn = updateBuffer,
        },
    };
}

pub fn deinit(self: *CursesRenderer) void {
    _ = curses.clear();
    _ = curses.endwin();
}

fn updateBuffer(renderer: *Renderer) void {}

fn refreshScreen(renderer: *Renderer) void {
    _ = curses.refresh();
}

fn drawFloorAndCeiling(renderer: *Renderer) void {
    const self = @fieldParentPtr(CursesRenderer, "renderer", renderer);
    const height = self.screen_height;
    const width = self.screen_width;
    const halfway_index = height / 2;

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const color: c_short = if (y > halfway_index) 7 else 0;
            const char: u8 = if (y > halfway_index) '"' else '.';
            //_ = curses.attron(curses.COLOR_PAIR(color));
            _ = curses.mvaddch(@intCast(c_int, y), @intCast(c_int, x), char);
            //_ = curses.attroff(curses.COLOR_PAIR(color));
        }
    }
}

fn drawCenteredColumn(renderer: *Renderer, x: u32, height: u32, colour: u32) void {
    const self = @fieldParentPtr(CursesRenderer, "renderer", renderer);
    const draw_height = if (height < self.screen_height) height else self.screen_height;
    const draw_y_start = if (height < self.screen_height) @as(usize, @divFloor(self.screen_height - height, 2)) else 0;

    var draw_y: usize = 0;
    const color: c_short = if (colour > 0x555555) 7 else 0;
    const char: u8 = if (colour > 0x555555) 'O' else '@';

    _ = curses.attron(curses.COLOR_PAIR(color));
    while (draw_y < draw_height) : (draw_y += 1) {
        _ = curses.mvaddch(@intCast(c_int, draw_y + draw_y_start), @intCast(c_int, x), char);
    }
    _ = curses.attroff(curses.COLOR_PAIR(color));
}

fn drawCenteredTexturedColumn(renderer: *Renderer, x: u32, height: u32, texels: []const u32) void {
    const self = @fieldParentPtr(CursesRenderer, "renderer", renderer);
    drawCenteredColumn(renderer, x, height, 0xFFFFFF);
}

pub fn drawRect(renderer: *Renderer, x: u32, y: u32, width: u32, height: u32, colour: Colour) void {}

pub fn drawLine(renderer: *Renderer, x1: u32, y1: u32, x2: u32, y2: u32, colour: Colour) void {}
