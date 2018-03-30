use @import("../system/index.zig");

error NotPngFile;
error NoMem;
error InvalidFormat;
error NoPixels;

const PNG_COLOR_TYPE_RGBA = c.PNG_COLOR_MASK_COLOR | c.PNG_COLOR_MASK_ALPHA;
const PNG_COLOR_TYPE_RGB  = c.PNG_COLOR_MASK_COLOR;

pub const PngImage = struct {
    width: u32,
    height: u32,
    pitch: u32,
    color_type: c_uint,
    raw: []u8,

    pub fn destroy(pi: &PngImage) void {
        mem.free(u8, pi.raw);
    }

    pub fn create(compressed_bytes: []const u8) %PngImage {
        var pi : PngImage = undefined;

        if (c.png_sig_cmp(&compressed_bytes[0], 0, 8) != 0) {
            return error.NotPngFile;
        }

        var png_ptr = c.png_create_read_struct(c.PNG_LIBPNG_VER_STRING, null, null, null);
        if (png_ptr == null) return error.NoMem;

        var info_ptr = c.png_create_info_struct(png_ptr);
        
        if (info_ptr == null) {
            c.png_destroy_read_struct(&png_ptr, null, null);
            return error.NoMem;
        }

        defer c.png_destroy_read_struct(&png_ptr, &info_ptr, null);

        c.png_set_sig_bytes(png_ptr, 8);

        var png_io = PngIo {
            .index = 8,
            .buffer = compressed_bytes,
        };
        c.png_set_read_fn(png_ptr, @ptrCast(&c_void, &png_io), read_png_data);

        c.png_read_info(png_ptr, info_ptr);

        pi.width  = c.png_get_image_width(png_ptr, info_ptr);
        pi.height = c.png_get_image_height(png_ptr, info_ptr);

        if (pi.width <= 0 or pi.height <= 0) return error.NoPixels;

        // bits per channel (not per pixel)
        const bits_per_channel = c.png_get_bit_depth(png_ptr, info_ptr);
        if (bits_per_channel != 8) return error.InvalidFormat;

        const channel_count = c.png_get_channels(png_ptr, info_ptr);
        const color_type = c.png_get_color_type(png_ptr, info_ptr);

        if(color_type == PNG_COLOR_TYPE_RGBA and channel_count == 4) {
            pi.color_type = c.GL_RGBA;
        } else if ( color_type == PNG_COLOR_TYPE_RGB and channel_count == 3) {
            pi.color_type = c.GL_RGB;
        } else {
            return error.InvalidFormat;
        }

        pi.pitch = pi.width * bits_per_channel * channel_count / 8;
        pi.raw = c.mem.alloc(u8, pi.height * pi.pitch) catch return error.NoMem;
        errdefer c.mem.free(pi.raw);

        const row_ptrs = c.mem.alloc(c.png_bytep, pi.height) catch return error.NoMem;
        defer c.mem.free(row_ptrs);

        { var i: usize = 0; while (i < pi.height) : (i += 1) {
            const q = (pi.height - i - 1) * pi.pitch;
            row_ptrs[i] = &pi.raw[q];
        }}

        c.png_read_image(png_ptr, &row_ptrs[0]);

        return pi;
    }
};

const PngIo = struct {
    index: usize,
    buffer: []const u8,
};

extern fn read_png_data(png_ptr: c.png_structp, data: c.png_bytep, length: c.png_size_t) void {
    const png_io = @ptrCast(&PngIo, @alignCast(@alignOf(PngIo), ??c.png_get_io_ptr(png_ptr)));
    const new_index = png_io.index + length;
    if (new_index > png_io.buffer.len) unreachable;
    @memcpy(@ptrCast(&u8, ??data), &png_io.buffer[png_io.index], length);
    png_io.index = new_index;
}


const TextureCache = struct {
    texture_map: HashMap([]const u8, Texture, hash_str, cmp_str),
    
    pub fn init()TextureCache {
        return TextureCache {
            .texture_map = HashMap([]const u8, Texture, hash_str, cmp_str).init(mem.c_allocator)
        };
    }

    pub fn getTexture(self: &TextureCache, texturePath: []const u8)Texture {
        if (map.get(texturePath)) | texture | {
            return texture;
        } else {
            const newTexture = texture(texturePath);
            self.texture_map.put(texturePath, newTexture);
            return newTexture;
        }
    }

    fn hash_str(x: i32)u32 {
        return *@ptrCast(&u32, &x);
    }

    fn cmp_str(a: i32, b: i32)bool {
        return a == b;
    }
};