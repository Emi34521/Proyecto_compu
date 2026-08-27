//librerías y modulos utilizados
const std = @import("std");
const rl = @import("raylib");
const ray = @import("logic_functions/ray_caster.zig");
const Map = @import("logic_functions/map_loader.zig");
const fr = @import("logic_functions/framebuffer.zig");
const playerI = @import("logic_functions/player.zig");
const artist = @import("logic_functions/artist.zig");
const spriteT = @import("logic_functions/sprite.zig");

const Clock = std.Io.Clock.real;

const width: i32 = 1900;
const height: i32 = 1070;
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
    // audio: se inicializa una sola vez, después de la ventana
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const music = try rl.loadMusicStream("src/resources/audio/song.wav");
    defer rl.unloadMusicStream(music);
    rl.setMusicVolume(music, 0.9);
    rl.playMusicStream(music);

    //Básicamente se carga primero el mapa del juego y se imprime en consola.
    var mapa = try Map.Mapa.load_map(io, gpa, "src/resources/mapa.txt");
    defer mapa.deinit(gpa);

    // sacamos las posiciones de las 'x' del mapa (spawns de mecha) y las
    // convertimos en sprites reales; extract_spawns ya deja esas celdas
    // como piso (' ') para que no cuenten como pared
    const mecha_positions = try mapa.extract_spawns(gpa, 'x', block_sz);
    defer gpa.free(mecha_positions);

    // dimensiones del mapa en celdas (la fila más larga manda, por si alguna
    // línea del .txt es más corta que las demás). No cambia durante el juego,
    // así que se calcula una sola vez aquí en vez de cada frame.
    var map_cols: usize = 0;
    for (mapa.cells) |row| {
        if (row.len > map_cols) map_cols = row.len;
    }
    const map_rows: usize = mapa.cells.len;
    const map_cols_f32: f32 = @floatFromInt(map_cols);
    const map_rows_f32: f32 = @floatFromInt(map_rows);

    var sprites = try gpa.alloc(spriteT.Sprite, mecha_positions.len);
    defer {
        for (sprites) |s| s.deinit();
        gpa.free(sprites);
    }
    for (mecha_positions, 0..) |pos, idx| {
        sprites[idx] = try spriteT.Sprite.init("src/resources/sprites/mecha.png", pos, 80);
    }

    var framestart = Clock.now(io);
    var dt: f32 = 1;

    const width_f32: f32 = @floatFromInt(width);
    const height_f32: f32 = @floatFromInt(height);
    const block_sz_f32: f32 = @floatFromInt(block_sz);
    const num_rays: usize = @intCast(width); // un rayo por columna de pantalla

    var view_mode: ViewMode = .first_person;

    const texture_size: usize = 64;

    // Arena para las asignaciones de cada frame (sprite_hits, hit_sprites
    // dentro de cast_ray). Se resetea entero cada frame en vez de liberar
    // cada asignación suelta, que sería mucho más lento con 800+ rayos/frame.
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();

    //espacio para las texturas de las paredes.
    var wall_textures = [_]rl.Image{
        try rl.loadImage("src/resources/textures/wall1.png"),
        try rl.loadImage("src/resources/textures/wall2.png"),
        try rl.loadImage("src/resources/textures/wall3.png"),
        try rl.loadImage("src/resources/textures/asosretroll.png"), // '0' y '*': secciones inaccesibles
    };
    //liberar la memoria
    defer for (wall_textures) |img| rl.unloadImage(img);

    for (&wall_textures) |*img| rl.imageFormat(img, .uncompressed_r8g8b8a8);

    while (!rl.windowShouldClose()) {
        defer {
            const now = Clock.now(io);
            const dt_ms: f32 = @floatFromInt(framestart.durationTo(now).toMilliseconds());
            dt = dt_ms / 1000.0;
            framestart = now;
        }
        rl.updateMusicStream(music);
        framebuffer.clear();

        // reseteamos la arena al inicio de cada frame: libera de un jalón
        // todo lo que cast_ray fue pidiendo durante el frame anterior
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();

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
                // raycasting: un rayo por columna de pantalla
                const num_rays_f32: f32 = @floatFromInt(num_rays);
                for (0..num_rays) |col| {
                    const col_f32: f32 = @floatFromInt(col);
                    const ray_angle = player.Angle - player.FOV / 2.0 + player.FOV * (col_f32 / num_rays_f32);

                    const hit = try ray.cast_ray(arena, mapa, player, ray_angle, texture_size, block_sz, sprites);
                    const corrected_distance = hit.distancia * @cos(ray_angle - player.Angle);
                    const wall_height = if (corrected_distance > 1)
                        (block_sz_f32 * height_f32) / corrected_distance
                    else
                        height_f32;

                    const wall_top: usize = @intFromFloat(@max(0.0, (height_f32 - wall_height) / 2.0));
                    const wall_bottom: usize = @intFromFloat(@min(height_f32, (height_f32 + wall_height) / 2.0));

                    if (hit.tipo_pared != ' ') {
                        const textura = wall_textures[textureIndexFor(hit.tipo_pared)];
                        const tex_width: usize = @intCast(textura.width);
                        const tex_height: usize = @intCast(textura.height);

                        var datos_textura: []u8 = undefined;
                        datos_textura.ptr = @ptrCast(textura.data);
                        datos_textura.len = tex_width * tex_height * 4; // RGBA = 4 bytes/pixel

                        const on_screen_height = wall_bottom - wall_top;
                        const x_pixel: usize = @min(
                            tex_width - 1,
                            @as(usize, @intFromFloat(hit.img_offset * @as(f32, @floatFromInt(tex_width)))),
                        );

                        for (wall_top..wall_bottom) |y| {
                            const y_scaled = @min(tex_height - 1, ((y - wall_top) * tex_height) / on_screen_height);
                            const text_idx = (y_scaled * tex_width + x_pixel) * 4;

                            const color = rl.Color{
                                .r = datos_textura[text_idx],
                                .g = datos_textura[text_idx + 1],
                                .b = datos_textura[text_idx + 2],
                                .a = datos_textura[text_idx + 3],
                            };

                            framebuffer.draw_pixel(col_f32, @floatFromInt(y), color) catch continue;
                        }
                    }

                    // --- sprites (mechas) que este rayo tocó antes de llegar a la pared ---
                    if (hit.sprite_hits) |hits| {
                        const half_screen_height = height_f32 / 2.0;

                        var sprite_idx: usize = hits.len - 1;
                        while (true) {
                            const sprite_hit = hits[sprite_idx];
                            const sprite_size_f32: f32 = @floatFromInt(sprite_hit.sprite.size);
                            // misma fórmula (y misma escala) que wall_height, pero con el
                            // tamaño real del sprite en vez del tamaño del bloque de pared;
                            // así ambos quedan directamente comparables en pantalla.
                            const draw_height: f32 = if (sprite_hit.distance > 1)
                                (sprite_size_f32 * height_f32) / sprite_hit.distance
                            else
                                height_f32;

                            var bottom_flt = half_screen_height - draw_height / 2.0;
                            if (bottom_flt < 0) bottom_flt = 0;
                            if (bottom_flt > height_f32) bottom_flt = height_f32;
                            const bottom: usize = @intFromFloat(bottom_flt);

                            var top_flt = half_screen_height + draw_height / 2.0;
                            if (top_flt < 0) top_flt = 0;
                            if (top_flt > height_f32) top_flt = height_f32;
                            const top: usize = @intFromFloat(top_flt);

                            if (top > bottom) {
                                const tex = sprite_hit.sprite.texture;
                                const tex_width: usize = @intCast(tex.width);
                                const tex_height: usize = @intCast(tex.height);
                                var tex_data: []u8 = undefined;
                                tex_data.ptr = @ptrCast(tex.data);
                                tex_data.len = tex_width * tex_height * 4;

                                const tex_x: usize = @min(
                                    tex_width - 1,
                                    @as(usize, @intFromFloat(sprite_hit.uvx * @as(f32, @floatFromInt(tex_width)))),
                                );
                                const strip_px = top - bottom;

                                for (bottom..top) |y| {
                                    const y_scaled = @min(tex_height - 1, ((y - bottom) * tex_height) / strip_px);
                                    const text_idx = (y_scaled * tex_width + tex_x) * 4;
                                    const alpha = tex_data[text_idx + 3];
                                    if (alpha == 0) continue; // pixel transparente del sprite: no lo dibujamos

                                    const color = rl.Color{
                                        .r = tex_data[text_idx],
                                        .g = tex_data[text_idx + 1],
                                        .b = tex_data[text_idx + 2],
                                        .a = alpha,
                                    };
                                    framebuffer.draw_pixel(col_f32, @floatFromInt(y), color) catch continue;
                                }
                            }

                            if (sprite_idx == 0) break;
                            sprite_idx -= 1;
                        }
                    }
                }

                // minimapa en la esquina superior izquierda
                const minimap_box: f32 = 320; // ancho/alto máximo del minimapa en píxeles
                const minimap_origin_x: usize = 15;
                const minimap_origin_y: usize = 15;

                const minimap_cell_f32 = @min(minimap_box / map_cols_f32, minimap_box / map_rows_f32);
                const minimap_cell_px: usize = @intFromFloat(@max(1.0, minimap_cell_f32));

                // fondo sólido detrás del minimapa: se dibuja del tamaño exacto
                // del mapa ya escalado, y luego render() pinta encima las paredes;
                // las celdas de piso (' ') se saltan en render(), así que quedan
                // mostrando este fondo, en vez del contenido de la vista 3D.
                framebuffer.set_current_color(.black);
                artist.square(
                    &framebuffer,
                    @intCast(minimap_origin_x),
                    @intCast(minimap_origin_y),
                    minimap_cell_px * map_cols,
                    minimap_cell_px * map_rows,
                );

                Map.Mapa.render(mapa, &framebuffer, minimap_cell_px, minimap_origin_x, minimap_origin_y);

                // jugador, escalado a la misma proporción que el minimapa
                const minimap_scale = @as(f32, @floatFromInt(minimap_cell_px)) / block_sz_f32;
                const minimap_marker_x: i32 = @as(i32, @intCast(minimap_origin_x)) +
                    @as(i32, @intFromFloat(player.position.x * minimap_scale));
                const minimap_marker_y: i32 = @as(i32, @intCast(minimap_origin_y)) +
                    @as(i32, @intFromFloat(player.position.y * minimap_scale));

                framebuffer.set_current_color(.yellow);
                artist.square(&framebuffer, minimap_marker_x - 2, minimap_marker_y - 2, 4, 4);
            },
            .top_down => {
                // tamaño de celda para esta vista, para que el mapa ENTERO
                // quepa en la pantalla (no el block_sz real del juego)
                const cell_px_f32 = @min(width_f32 / map_cols_f32, height_f32 / map_rows_f32);
                const cell_px: usize = @intFromFloat(@max(1.0, cell_px_f32));

                Map.Mapa.render(mapa, &framebuffer, cell_px, 0, 0);

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
fn textureIndexFor(wall_char: u8) usize {
    return switch (wall_char) {
        '-' => 0,
        '|' => 1,
        '+' => 2,
        '0', '*' => 3,
        else => 0,
    };
}
