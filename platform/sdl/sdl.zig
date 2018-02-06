const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const assert = @import("std").debug.assert;
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

const SDL_Event = extern struct {
    _type: c.Uint32,
    _union: [56]u8,
};
extern fn SDL_PollEvent(event: &SDL_Event)c_int;

// SDL_RWclose is fundamentally unrepresentable in Zig, because `ctx` is
// evaluated twice. One could make the case that this is a bug in SDL,
// especially since the docs list a real function prototype that would not
// have this double-evaluation of the parameter.
// If SDL would instead of a macro use a static inline function,
// it would resolve the SDL bug as well as make the function visible to Zig
// and to debuggers.
// SDL_rwops.h:#define SDL_RWclose(ctx)        (ctx)->close(ctx)
inline fn SDL_RWclose(ctx: &c.SDL_RWops)c_int {
    const aligned_ctx = @alignCast(@alignOf(my_SDL_RWops), ctx);
    const casted_ctx = @ptrCast(&my_SDL_RWops, aligned_ctx);
    return casted_ctx.close(casted_ctx);
}

// Zig does not support extern unions yet.
// See https://github.com/zig-lang/zig/issues/144
const my_SDL_RWops = extern struct {
    size: extern fn(),
    seek: extern fn(),
    read: extern fn(),
    write: extern fn(),
    close: extern fn(context: &my_SDL_RWops)->c_int,
};

error SDLInitializationFailed;

pub fn main() %void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow(c"My Game Window",
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            300, 73,
            c.SDL_WINDOW_OPENGL) ??
    {
        c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, 0) ?? {
        c.SDL_Log(c"Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const zig_bmp = @embedFile("zig.bmp");
    const rw = c.SDL_RWFromConstMem(@ptrCast(&c_void, &zig_bmp[0]), c_int(zig_bmp.len)) ?? {
        c.SDL_Log(c"Unable to get RWFromConstMem: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer assert(SDL_RWclose(rw) == 0);

    const zig_surface = c.SDL_LoadBMP_RW(rw, 0) ?? {
        c.SDL_Log(c"Unable to load bmp: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_FreeSurface(zig_surface);

    const zig_texture = c.SDL_CreateTextureFromSurface(renderer, zig_surface) ?? {
        c.SDL_Log(c"Unable to create texture from surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyTexture(zig_texture);

    var quit = false;
    while (!quit) {
        var event: SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            switch (event._type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, zig_texture, null, null);
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(17);
    }
}