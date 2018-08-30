void DrawText(SpriteFont spriteFont, const char *text, Vector2 position, float fontSize, int spacing, Color tint) {
}

Vector2 MeasureText(SpriteFont spriteFont, const char *text, float fontSize, int spacing) {
}

int GetCharIndex(SpriteFont font, int letter) {
    int index = 0;
    for (font.chars) | u8, i | {
        if (font.chars[i].value == letter) {
            index = i;
            break;
        }
    }
    return index;
}
const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;

const Draw = @import("draw.zig");
const Platform = @import("platform/index.zig");
const loadPcx = @import("load_pcx.zig").loadPcx;

const FONT_FILENAME = "../assets/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  tileset: Draw.Tileset,
};

pub fn loadFont(dsaf: *DoubleStackAllocatorFlat, font: *Font) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const img = try loadPcx(dsaf, FONT_FILENAME, 0);

  font.tileset = Draw.Tileset{
    .texture = Platform.uploadTexture(img),
    .xtiles = FONT_NUM_COLS,
    .ytiles = FONT_NUM_ROWS,
  };
}

pub fn fontDrawString(ps: *Platform.State, font: *const Font, x: i32, y: i32, string: []const u8) void {
  var ix = x;
  const w = FONT_CHAR_WIDTH;
  const h = FONT_CHAR_HEIGHT;
  for (string) |char| {
    const fx = @intToFloat(f32, ix);
    const fy = @intToFloat(f32, y);
    const tile = Draw.Tile{
      .tx = char % FONT_NUM_COLS,
      .ty = char / FONT_NUM_COLS,
    };
    Platform.drawTile(ps, &font.tileset, tile, fx, fy, w, h, Draw.Transform.Identity);
    ix += FONT_CHAR_WIDTH;
  }
}
