const t = @import("../index.zig");

pub const Spritesheet = struct {
    img: PngImage,
    count: usize,
    width: usize,
    height: usize,
    texture_id: c.GLuint,
    vertex_buffer: c.GLuint,
    tex_coord_buffers: []c.GLuint,

    pub fn init(compressed_bytes: []const u8, w: usize, h: usize) !Spritesheet {
        var s: Spritesheet = undefined;

        s.img = try PngImage.create(compressed_bytes);
        const col_count = s.img.width / w;
        const row_count = s.img.height / h;
        s.width = w;
        s.height = h;
        s.count = col_count * row_count;

        c.glGenTextures(1, &s.texture_id);
        errdefer c.glDeleteTextures(1, &s.texture_id);

        c.glBindTexture(c.GL_TEXTURE_2D, s.texture_id);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glPixelStorei(c.GL_PACK_ALIGNMENT, 4);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, c_int(s.img.width), c_int(s.img.height),
                0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, @ptrCast(&c_void, &s.img.raw[0]));

        c.glGenBuffers(1, &s.vertex_buffer);
        errdefer c.glDeleteBuffers(1, &s.vertex_buffer);

        const vertices = [][3]c.GLfloat {
            []c.GLfloat{0.0,          0.0,          0.0},
            []c.GLfloat{0.0,          c.GLfloat(h), 0.0},
            []c.GLfloat{c.GLfloat(w), 0.0,          0.0},
            []c.GLfloat{c.GLfloat(w), c.GLfloat(h), 0.0},
        };

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.vertex_buffer);
        c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 3 * @sizeOf(c.GLfloat), @ptrCast(&c_void, &vertices[0][0]), c.GL_STATIC_DRAW);

        s.tex_coord_buffers = c.mem.alloc(c.GLuint, s.count) catch return error.NoMem;
        errdefer c.mem.free(s.tex_coord_buffers);

        c.glGenBuffers(c.GLint(s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);
        errdefer c.glDeleteBuffers(c.GLint(s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);

        for (s.tex_coord_buffers) |tex_coord_buffer, i| {
            const upside_down_row = i / col_count;
            const col = i % col_count;
            const row = row_count - upside_down_row - 1;

            const x = f32(col * w);
            const y = f32(row * h);

            const img_w = f32(s.img.width);
            const img_h = f32(s.img.height);
            const tex_coords = [][2]c.GLfloat {
                []c.GLfloat{ x / img_w, (y + f32(h)) / img_h, },
                []c.GLfloat{ x / img_w, y / img_h, },
                []c.GLfloat{ (x + f32(w)) / img_w, (y + f32(h)) / img_h, },
                []c.GLfloat{ (x + f32(w)) / img_w, y / img_h, },
            };

            c.glBindBuffer(c.GL_ARRAY_BUFFER, tex_coord_buffer);
            c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(&c_void, &tex_coords[0][0]), c.GL_STATIC_DRAW);
        }

        return s;
    }

    pub fn draw(s: *Spritesheet, shader: *TextureShader, index: usize, mvp: *const Mat4) void {
        shader.program.bind();
        shader.program.setUniform_mat4(shader.uniform_mvp, mvp);
        shader.program.setUniform_int(shader.uniform_tex, c.GLint(s.texture_id));

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.vertex_buffer);
        c.glEnableVertexAttribArray(c.GLuint(shader.attrib_position));
        c.glVertexAttribPointer(c.GLuint(shader.attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.tex_coord_buffers[index]);
        c.glEnableVertexAttribArray(c.GLuint(shader.attrib_uv));
        c.glVertexAttribPointer(c.GLuint(shader.attrib_uv), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

        c.glActiveTexture(c.GL_TEXTURE0 + s.texture_id);
        c.glBindTexture(c.GL_TEXTURE_2D, s.texture_id);

        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
    
    pub fn deinit(s: *Spritesheet) void {
        c.glDeleteBuffers(c.GLint(s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);
        mem.free(c.GLuint, s.tex_coord_buffers);
        c.glDeleteBuffers(1, &s.vertex_buffer);
        c.glDeleteTextures(1, &s.texture_id);

        s.img.destroy();
    }
};