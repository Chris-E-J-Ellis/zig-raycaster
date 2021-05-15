const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

// Not too fussed about this, just trying get SDL working, and out of the way!
pub const Window = sdl.SDL_Window;
pub const Renderer = sdl.SDL_Renderer;
pub const Texture = sdl.SDL_Texture;
pub const Surface = sdl.SDL_Surface;
pub const Rect = sdl.SDL_Rect;
pub const Color = sdl.SDL_Color;

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);

pub fn initVideo() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
}

pub fn createWindow(width: usize, height: usize) !*sdl.SDL_Window {
    const c_width = @intCast(c_int, width);
    const c_height = @intCast(c_int, height);

    return sdl.SDL_CreateWindow("Cast Some Rays", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, c_width, c_height, sdl.SDL_WINDOW_RESIZABLE) orelse {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn createRendererFromWindow(screen: *sdl.SDL_Window) !*sdl.SDL_Renderer {
    return sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn createRGBSurface(width: usize, height: usize) !*sdl.SDL_Surface {
    const surfaceDepth = 32;
    const c_width = @intCast(c_int, width);
    const c_height = @intCast(c_int, height);

    return sdl.SDL_CreateRGBSurface(0, c_width, c_height, surfaceDepth, 0, 0, 0, 0) orelse {
        sdl.SDL_Log("Unable to create surface", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn createTextureFromSurface(renderer: *sdl.SDL_Renderer, surface: *sdl.SDL_Surface) !*sdl.SDL_Texture {
    return sdl.SDL_CreateTextureFromSurface(renderer, surface) orelse {
        sdl.SDL_Log("Unable to create texture from surface: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn renderBuffer(renderer: *sdl.SDL_Renderer, texture: *sdl.SDL_Texture, buffer: []u32, width: usize) void {
    const bytesPerPixel = 4;
    const pitch = @intCast(c_int, width * bytesPerPixel);
    _ = sdl.SDL_UpdateTexture(texture, null, &buffer[0], pitch);
    _ = sdl.SDL_RenderCopy(renderer, texture, null, null);
}

pub fn refreshScreen(renderer: *sdl.SDL_Renderer) void {
    _ = sdl.SDL_RenderPresent(renderer);
    _ = sdl.SDL_RenderClear(renderer);
}

pub fn drawRect(renderer: *sdl.SDL_Renderer, x: usize, y: usize, width: usize, height: usize, color: Color) void {
    const rect = Rect{ .x = @intCast(c_int, x), .y = @intCast(c_int, y), .w = @intCast(c_int, width), .h = @intCast(c_int, height) };

    _ = sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
    _ = sdl.SDL_RenderDrawRect(renderer, &rect);
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
}

pub fn drawLine(renderer: *sdl.SDL_Renderer, x1: usize, y1: usize, x2: usize, y2: usize, color: Color) void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
    _ = sdl.SDL_RenderDrawLine(renderer, @intCast(c_int, x1), @intCast(c_int, y1), @intCast(c_int, x2), @intCast(c_int, y2));
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
}

pub fn destroyTexture(texture: *sdl.SDL_Texture) void {
    sdl.SDL_DestroyTexture(texture);
}

pub fn freeSurface(surface: *sdl.SDL_Surface) void {
    sdl.SDL_FreeSurface(surface);
}

pub fn destroyRenderer(renderer: *sdl.SDL_Renderer) void {
    sdl.SDL_DestroyRenderer(renderer);
}

pub fn destroyWindow(screen: *sdl.SDL_Window) void {
    sdl.SDL_DestroyWindow(screen);
}

pub fn quit() void {
    sdl.SDL_Quit();
}

pub const ScanCode = enum(c_int) {
    a = sdl.SDL_SCANCODE_A,
    d = sdl.SDL_SCANCODE_D,
    i = sdl.SDL_SCANCODE_I,
    k = sdl.SDL_SCANCODE_K,
    l = sdl.SDL_SCANCODE_L,
    m = sdl.SDL_SCANCODE_M,
    g = sdl.SDL_SCANCODE_G,
    s = sdl.SDL_SCANCODE_S,
    t = sdl.SDL_SCANCODE_T,
    w = sdl.SDL_SCANCODE_W,
    x = sdl.SDL_SCANCODE_X,
};

pub const KeyboardState = struct {
    state: []const u8,

    pub fn isPressed(self: KeyboardState, scanCode: ScanCode) bool {
        return self.state[@intCast(usize, @enumToInt(scanCode))] == 1;
    }
};

pub fn getKeyboardState() KeyboardState {
    var len: c_int = undefined;
    var keysArray = sdl.SDL_GetKeyboardState(&len);
    return KeyboardState{ .state = keysArray[0..@intCast(usize, len)] };
}

// Some good inspiration from xq's sdl bindings on how to handle this stuff.
pub const Event = union(enum) {
    quit: sdl.SDL_QuitEvent,
    unhandled: void,

    fn from(event: sdl.SDL_Event) Event {
        return switch (event.type) {
            sdl.SDL_QUIT => Event{ .quit = event.quit },
            else => Event.unhandled,
        };
    }
};

pub fn pollEvent() ?Event {
    var event: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&event) != 0) {
        return Event.from(event);
    }
    return null;
}
