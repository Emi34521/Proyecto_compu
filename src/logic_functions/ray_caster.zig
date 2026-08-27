//función para realizar todos los cálculos del raycasting y dibujar en el framebuffer
const std = @import("std");
const playerI = @import("player.zig");
const mapT = @import("map_loader.zig");
const fr = @import("framebuffer.zig");
const rl = @import("raylib");
const artist = @import("artist.zig");
const spriteT = @import("sprite.zig");
const Sprite = spriteT.Sprite;

pub const SpriteHit = struct {
    sprite: Sprite,
    distance: f32,
    uvx: f32,
};

pub const intersecto = struct {
    distancia: f32,
    tipo_pared: u8,
    img_offset: f32,
    sprite_hits: ?[]SpriteHit,
};

pub fn cast_ray(
    arena: std.mem.Allocator,
    current_map: mapT.Mapa,
    player: playerI.Player,
    angle: f32,
    texture_size: usize,
    block_size: usize,
    sprites: []const Sprite,
) !intersecto {
    _ = texture_size; // reservado para cuando muestreemos la textura real con img_offset

    var sprite_hits: std.ArrayList(SpriteHit) = .empty;
    // sin defer .deinit(arena): asumiendo arena, se libera toda junta al final del frame

    const hit_sprites = try arena.alloc(bool, sprites.len);
    // sin defer arena.free(...): mismo motivo, asumiendo arena
    @memset(hit_sprites, false);

    const block_sz: f32 = @floatFromInt(block_size);
    const max_distancia: f32 = 2000; // evita que el rayo busque para siempre si no hay pared
    const cos_a = @cos(angle);
    const sin_a = @sin(angle);

    var d: f32 = max_distancia;
    var cell_type: u8 = ' ';
    var img_off: f32 = 0;

    var distancia: f32 = 0;
    while (distancia < max_distancia) : (distancia += 2) {
        const world_x = cos_a * distancia + player.position.x;
        const world_y = sin_a * distancia + player.position.y;

        if (world_x < 0 or world_y < 0) {
            d = distancia;
            cell_type = '#';
            img_off = 0;
            break;
        }

        const i: usize = @intFromFloat(world_x / block_sz); // columna
        const j: usize = @intFromFloat(world_y / block_sz); // fila

        if (j >= current_map.cells.len or i >= current_map.cells[j].len) {
            d = distancia;
            cell_type = '#';
            img_off = 0;
            break;
        }

        if (current_map.cells[j][i] != ' ') {
            d = distancia;
            cell_type = current_map.cells[j][i];

            // posición dentro de la celda (0..1 en cada eje) para saber qué
            // franja de la textura le toca a este punto de impacto
            const frac_x = @mod(world_x, block_sz) / block_sz;
            const frac_y = @mod(world_y, block_sz) / block_sz;
            const dist_borde_vertical = @min(frac_x, 1 - frac_x);
            const dist_borde_horizontal = @min(frac_y, 1 - frac_y);
            img_off = if (dist_borde_vertical < dist_borde_horizontal) frac_y else frac_x;
            break;
        }

        // revisamos sprites en cada paso del rayo, antes de llegar a la pared
        for (sprites, 0..) |sprite, idx| {
            if (hit_sprites[idx]) continue;

            const sprite_size_f32: f32 = @floatFromInt(sprite.size);
            const half_sprite_size = sprite_size_f32 / 2;

            const dx = sprite.position.x - world_x;
            const dy = sprite.position.y - world_y;
            const dist_to_sprite = @sqrt(dx * dx + dy * dy);

            if (dist_to_sprite < half_sprite_size) {
                hit_sprites[idx] = true;
                try sprite_hits.append(arena, .{
                    .sprite = sprite,
                    .distance = distancia,
                    .uvx = dist_to_sprite / sprite_size_f32,
                });
            }
        }
    }

    return .{
        .distancia = d,
        .tipo_pared = cell_type,
        .img_offset = img_off,
        .sprite_hits = if (sprite_hits.items.len > 0) sprite_hits.items else null,
    };
}
