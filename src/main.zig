//librerías y modulos utilizados
const std = @import("std");
const rl = @import("raylib");
const ray = @import("logic_functions/ray_caster.zig");
const Map = @import("logic_functions/map_loader.zig");
const fr = @import("logic_functions/framebuffer.zig");
const playerI = @import("logic_functions/player.zig");
const artist = @import("logic_functions/artist.zig");

const Clock = std.Io.Clock.real;

const width: i32 = 1200;
const height: i32 = 900;
const block_sz: usize = 100;

const ViewMode = enum { first_person, top_down };

pub fn main(init: std.process.Init) !void {
    // std.process.Init ya nos da un allocator y un io listos para usar,
    // no hace falta armar uno manualmente.
    const gpa = init.gpa;
    const io = init.io;

    var player = playerI.Player{
        .position = rl.Vector2{ .x = 150, .y = 150 },
        .Angle = 0.0,
        .FOV = std.math.pi / 3.0, // Campo de visión de 60 grados
        .speed = 350.0,
        .rotation_speed = std.math.pi / 2.0, // Velocidad de rotación de 90 grados por segundo
    };

    var framebuffer = fr.Framebuffer.init(width, height, .black);
    rl.initWindow(width, height, "proyectoXD");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    //Básicamente se carga primero el mapa del juego y se imprime en consola.
    var mapa = try Map.Mapa.load_map(io, gpa, "src/resources/mapa.txt");
    defer mapa.deinit(gpa);

    var framestart = Clock.now(io);
    var dt: f32 = 1;

    const width_f32: f32 = @floatFromInt(width);
    const height_f32: f32 = @floatFromInt(height);
    const block_sz_f32: f32 = @floatFromInt(block_sz);
    const num_rays: usize = @intCast(width); // un rayo por columna de pantalla

    var view_mode: ViewMode = .first_person;
    var corrected_distance: f32 = undefined;

    while (!rl.windowShouldClose()) {
        defer {
            const now = Clock.now(io);
            const dt_ms: f32 = @floatFromInt(framestart.durationTo(now).toMilliseconds());
            dt = dt_ms / 1000.0;
            framestart = now;
        }
        framebuffer.clear();

        // Controles
        if (rl.isKeyDown(.a)) {
            player.Angle -= player.rotation_speed * dt;
        }
        if (rl.isKeyDown(.d)) {
            player.Angle += player.rotation_speed * dt;
        }

        //Sección graciosa, esta es la parte de "colisiones" se utiliza la función de "isWall" para indicar que el jugador
        //se puede mover únicamente si no está "dentro" o al menos cerca de una pared. No obstante, cuenta con un "bug" que es,
        // hasta cierto punto, intencional. Al no incluir el tercer if de esta parte, si el jugador se acerca demasiado a una pared,
        // este se quedaría atascado hasta reiniciar el juego. Por este motivo, el último if intenta solucionar esto, siguiendo la lógica
        // de que si se llega a topar por completo con una pared, el jugador retrocederá un poco para continuar con su movilidad normal.
        // Aquí aparece el "bug" el jugador puede atravezar paredes si camina hacía atrás. Lo dejaré como algo curioso y para futuras
        //pruebas resultará útil y me ahorrará tiempo. Además que me permitirá añadir "easter eggs" dentro del juego.

        if ((rl.isKeyDown(.w)) and !(mapa.isWall(player.position.x, player.position.y, block_sz))) {
            player.position.x += @cos(player.Angle) * player.speed * dt;
            player.position.y += @sin(player.Angle) * player.speed * dt;
        }
        if ((rl.isKeyDown(.s)) and !(mapa.isWall(player.position.x, player.position.y, block_sz))) {
            player.position.x -= @cos(player.Angle) * player.speed * dt;
            player.position.y -= @sin(player.Angle) * player.speed * dt;
        }
        if (mapa.isWall(player.position.x, player.position.y, block_sz)) {
            player.position.x -= @cos(player.Angle) * player.speed * dt;
            player.position.y -= @sin(player.Angle) * player.speed * dt;
        }

        // isKeyPressed (no isKeyDown) para que cambie de vista UNA vez por
        // pulsación, no 60 veces por segundo mientras la tecla está abajo.
        if (rl.isKeyPressed(.k)) {
            view_mode = switch (view_mode) {
                .first_person => .top_down,
                .top_down => .first_person,
            };
        }

        switch (view_mode) {
            .first_person => {
                // --- raycasting: un rayo por columna de pantalla ---
                const num_rays_f32: f32 = @floatFromInt(num_rays);
                for (0..num_rays) |col| {
                    const col_f32: f32 = @floatFromInt(col);
                    const ray_angle = player.Angle - player.FOV / 2.0 + player.FOV * (col_f32 / num_rays_f32);

                    const hit = ray.cast_ray(player, mapa, ray_angle);

                    // corrige el efecto "ojo de pez" proyectando la distancia sobre el eje de la cámara
                    corrected_distance = hit.distancia * @cos(ray_angle - player.Angle);
                    const wall_height = if (corrected_distance > 1)
                        (block_sz_f32 * height_f32) / corrected_distance
                    else
                        height_f32;

                    const wall_top: usize = @intFromFloat(@max(0.0, (height_f32 - wall_height) / 2.0));
                    const wall_bottom: usize = @intFromFloat(@min(height_f32, (height_f32 + wall_height) / 2.0));

                    const color: rl.Color = switch (hit.tipo_pared) {
                        '+' => .blue,
                        '-' => .red,
                        '|' => .blue,
                        ' ' => continue, // no se encontró pared en el rango: dejamos el fondo tal cual
                        else => .gray, // símbolo de mapa no reconocido (nos avisa de un bug en el mapa)
                    };

                    for (wall_top..wall_bottom) |y| {
                        framebuffer.draw_pixel(col_f32, @floatFromInt(y), color) catch continue;
                    }
                }
            },
            .top_down => {
                // calculamos cuántas columnas/filas tiene el mapa (la fila
                // más larga manda, por si alguna línea del .txt es más corta)
                var map_cols: usize = 0;
                for (mapa.cells) |row| {
                    if (row.len > map_cols) map_cols = row.len;
                }
                const map_rows_f32: f32 = @floatFromInt(mapa.cells.len);
                const map_cols_f32: f32 = @floatFromInt(map_cols);

                // tamaño de celda para esta vista, para que el mapa ENTERO
                // quepa en la pantalla (no el block_sz real del juego)
                const cell_px_f32 = @min(width_f32 / map_cols_f32, height_f32 / map_rows_f32);
                const cell_px: usize = @intFromFloat(@max(1.0, cell_px_f32));

                Map.Mapa.render(mapa, &framebuffer, cell_px);

                // punto del jugador, escalado igual que el mapa: convertimos
                // su posición real (en unidades de block_sz) a la escala del minimapa
                const scale = cell_px_f32 / block_sz_f32;
                const marker_x: i32 = @intFromFloat(player.position.x * scale);
                const marker_y: i32 = @intFromFloat(player.position.y * scale);

                framebuffer.set_current_color(.yellow);
                artist.square(&framebuffer, marker_x - 3, marker_y - 3, 6, 6);
            },
        }

        try framebuffer.swap();
    }
}
