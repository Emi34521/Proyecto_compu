//función para realizar todos los cálculos del raycasting y dibujar en el framebuffer
const playerI = @import("player.zig");
const mapT = @import("logic_functions/map_loader.zig");
const fr = @import("logic_functions/framebuffer.zig");
const rl = @import("raylib");
const artist = @import("logic_functions/artist.zig");
pub const intersecto = struct {
    distancia: f32,
    tipo_pared: u8,
};

fn cast_ray(player: playerI.Player, map: mapT.Mapa) intersecto {
    const block_sz = 100;

    var distancia: f32 = 0;
    while (true) : (distancia += 10) {
        defer distancia += 10;
        const off_x: f32 = @cos(player.Angle) * distancia;
        const off_y: f32 = @sin(player.Angle) * distancia;

        const x: usize = @trunc(off_x + player.position.x);
        const y: usize = @trunc(off_y + player.position.y);

        const i: usize = x / block_sz;
        const j: usize = y / block_sz;

        if (map.cells[i][j] != ' ') {
            return .{
                .distancia = distancia,
                .tipo_pared = map.cells[j][i],
            };
        }
    }
}
