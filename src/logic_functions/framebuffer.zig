const rl = @import("raylib");

pub const Framebuffer = struct {
    width: i32,
    height: i32,
    image: rl.Image,
    texture: ?rl.Texture,
    background_color: rl.Color,
    current_color: rl.Color,

    pub fn init(width: i32, height: i32, color: rl.Color) Framebuffer {
        return Framebuffer{
            .width = width,
            .height = height,
            .image = rl.genImageColor(width, height, color),
            .background_color = color,
            .current_color = color,
            .texture = null,
        };
    }

    pub fn draw_line(self: *Framebuffer, d0: rl.Vector2, d1: rl.Vector2, color: rl.Color) void {
        self.image.drawLineV(d0, d1, color);
    }

    pub fn draw_pixel(self: *Framebuffer, x: f32, y: f32, color: rl.Color) !void {
        const i32_x: i32 = @intFromFloat(x);
        const i32_y: i32 = @intFromFloat(y);

        if (i32_x >= self.width) return error.BadCoordinates;
        if (i32_y >= self.height) return error.BadCoordinates;

        if (i32_x < 0) return error.BadCoordinates;
        if (i32_y < 0) return error.BadCoordinates;

        self.image.drawPixel(i32_x, i32_y, color);
    }

    pub fn clear(self: *Framebuffer) void {
        self.image.clearBackground(self.background_color);
        // Si no ponemos esto, se muere la compu. Pruebenlo, pero ahí le dan ctrl+c
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
            self.texture = null;
        }
    }

    // Cambia el color con el que se dibuja (paredes, sprites, etc.),
    // separado del background_color para que clear() no lo herede por error.
    pub fn set_current_color(self: *Framebuffer, color: rl.Color) void {
        self.current_color = color;
    }

    pub fn renderToFile(self: *Framebuffer, filename: [:0]const u8) !void {
        if (!self.image.exportToFile(filename)) return error.CouldntWriteFile;
    }

    pub fn swap(self: *Framebuffer) !void {
        rl.beginDrawing();
        defer rl.endDrawing();

        self.texture = try rl.loadTextureFromImage(self.image);
        rl.drawTexture(self.texture.?, 0, 0, .white);
        rl.drawFPS(1900 - 100, 20);
        //equivalente a
        // if (self.texture) |texture| {
        //     rl.drawTexture(texture, 0, 0, .white);
        // } else unreachable;
    }
};
