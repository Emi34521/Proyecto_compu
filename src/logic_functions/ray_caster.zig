//función para realizar todos los cálculos del raycasting y dibujar en el framebuffer
const playerI = @import("player.zig");
const mapT = @import("map_loader.zig");
const fr = @import("framebuffer.zig");
const rl = @import("raylib");
const artist = @import("artist.zig");

pub const intersecto = struct {
    distancia: f32,
    tipo_pared: u8,
};

// angle: dirección del rayo específico (distinto a player.Angle cuando
// estamos lanzando varios rayos a lo largo del FOV)
pub fn cast_ray(player: playerI.Player, map: mapT.Mapa, angle: f32) intersecto {
    const block_sz: f32 = 100;
    const max_distancia: f32 = 2000; // evita que el rayo busque para siempre si no hay pared

    var distancia: f32 = 0;
    while (distancia < max_distancia) : (distancia += 10) {
        const off_x: f32 = @cos(angle) * distancia;
        const off_y: f32 = @sin(angle) * distancia;

        const world_x = off_x + player.position.x;
        const world_y = off_y + player.position.y;

        // si el rayo se sale del mundo por la izquierda/arriba, lo tratamos como pared
        if (world_x < 0 or world_y < 0) {
            return .{ .distancia = distancia, .tipo_pared = '#' };
        }

        const i: usize = @intFromFloat(world_x / block_sz); // columna
        const j: usize = @intFromFloat(world_y / block_sz); // fila

        // si el rayo se sale del mapa cargado, lo tratamos como pared para no crashear
        if (j >= map.cells.len or i >= map.cells[j].len) {
            return .{ .distancia = distancia, .tipo_pared = '#' };
        }

        if (map.cells[j][i] != ' ') {
            return .{ .distancia = distancia, .tipo_pared = map.cells[j][i] };
        }
    }

    // no se encontró ninguna pared dentro del rango máximo
    return .{ .distancia = max_distancia, .tipo_pared = ' ' };
}
