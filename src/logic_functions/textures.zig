// Carga y muestreo de texturas de pared.
const std = @import("std");
const rl = @import("raylib");

pub const WallTextures = struct {
    brick: rl.Image, // '-'
    metal: rl.Image, // '|'
    concrete: rl.Image, // '+'
    default: rl.Image, // cualquier símbolo sin textura asignada (ej. '#')

    pub fn load() !WallTextures {
        var self: WallTextures = .{
            .brick = try rl.loadImage("src/resources/textures/wall1.png"),
            .metal = try rl.loadImage("src/resources/textures/wall2.png"),
            .concrete = try rl.loadImage("src/resources/textures/wall3.png"),
            .default = try rl.loadImage("src/resources/textures/wall4.png"),
        };
        // forzamos RGBA de 8 bits (4 bytes/pixel) en las 4, sin importar si el
        // PNG original traía o no canal alpha, para que la indexación de
        // sample() (x*4) siempre sea válida.
        rl.imageFormat(&self.brick, .uncompressed_r8g8b8a8);
        rl.imageFormat(&self.metal, .uncompressed_r8g8b8a8);
        rl.imageFormat(&self.concrete, .uncompressed_r8g8b8a8);
        rl.imageFormat(&self.default, .uncompressed_r8g8b8a8);
        return self;
    }

    pub fn deinit(self: WallTextures) void {
        rl.unloadImage(self.brick);
        rl.unloadImage(self.metal);
        rl.unloadImage(self.concrete);
        rl.unloadImage(self.default);
    }

    // decide qué imagen le toca a cada tipo de pared del mapa
    pub fn get(self: WallTextures, tipo_pared: u8) rl.Image {
        return switch (tipo_pared) {
            '-' => self.brick,
            '|' => self.metal,
            '+' => self.concrete,
            else => self.default,
        };
    }
};

// Muestrea un color de la textura dado u (horizontal, viene de hit.img_offset)
// y v (vertical, la posición dentro de la franja de pared que se está dibujando),
// ambos en el rango [0, 1). Lee directo los bytes crudos de la imagen (RGBA,
// 4 bytes por pixel)
pub fn sample(img: rl.Image, u: f32, v: f32) rl.Color {
    const u_clamped = std.math.clamp(u, 0.0, 0.999);
    const v_clamped = std.math.clamp(v, 0.0, 0.999);

    const width_f32: f32 = @floatFromInt(img.width);
    const height_f32: f32 = @floatFromInt(img.height);

    const x: usize = @intFromFloat(u_clamped * width_f32);
    const y: usize = @intFromFloat(v_clamped * height_f32);
    const width_usize: usize = @intCast(img.width);

    const datos_textura: [*]u8 = @ptrCast(img.data);
    const text_idx: usize = (y * width_usize + x) * 4; // 4 bytes/pixel: RGBA

    return rl.Color{
        .r = datos_textura[text_idx],
        .g = datos_textura[text_idx + 1],
        .b = datos_textura[text_idx + 2],
        .a = datos_textura[text_idx + 3],
    };
}
