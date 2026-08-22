//librerías y modulos utilizados
const std = @import("std");
const rl = @import("raylib");
const ray = @import("logic_functions/ray_caster.zig");
const Map = @import("logic_functions/map_loader.zig");
const fr = @import("logic_functions/framebuffer.zig");
const playerI = @import("player.zig");
const builtin = @import("builtin");

const Clock = std.Io.Clock.real;

const width: i32 = 800;
const height: i32 = 600;
const block_sz: usize = 100;

pub fn main(init: std.process.Init) !void {
    const gpa: std.mem.Allocator = switch (builtin.mode) {
        .Debug, .ReleaseSafe => alloc.Allocator(),
        .ReleaseFast, .RealeaseSmall => {},
    };
    defer switch (builtin.mode) {
        .Debug, .ReleaseSafe => gpa.deinit(),
        .ReleaseFast, .RealeaseSmall => {},
    };
    var player = playerI.Player{
        .position = fr.Point{ .x = 150, .y = 150 },
        .Angle = 0.0,
        .FOV = std.math.pi / 3.0, // Campo de visión de 60 grados
        .speed = 100.0,
        .rotation_speed = std.math.pi / 2.0, // Velocidad de rotación de 90 grados por segundo
    };
    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();
    var framebuffer = fr.Framebuffer.init(width, height);
    rl.initWindow(width, height, "proyectoXD");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    //Básicamente se carga primero el mapa del juego y se imprime en consola.
    var mapa = try Map.Mapa.load_map(init.io, init.gpa, "src/resources/mapa.txt");
    defer mapa.deinit(init.gpa);

    var framestart = Clock.now(io);
    var dt: f32 = 1;

    while (!rl.windowShouldClose()) {
        defer {
            const now = Clock.now(io);
            const dt_ms = @floatFromInt(framestart.durationTo(now).toMilliseconds());
            dt = dt_ms / 1000.0;
            framestart = now;
        }
        fr.Framebuffer.clear();

        if (rl.isKeyDown(.a)) {
            player.Angle -= player.rotarion_speed * dt;
        }
        if (rl.isKeyDown(.d)) {
            player.Angle += player.rotarion_speed * dt;
        }
        if (rl.isKeyDown(.w)) {
            player.position.x += @cos(player.Angle) * player.speed * dt;
            player.position.y += @sin(player.Angle) * player.speed * dt;
        }
        if (rl.isKeyDown(.s)) {
            player.position.y -= @sin(player.Angle) * 5 * dt;
            player.position.x -= @cos(player.Angle) * 5 * dt;
        }

        Map.render(&rl.getFramebuffer(), block_sz);
        playerI.Angle += std.math.pi / 60.0; // Incrementa el ángulo del jugador en 1 grado por frame
        const ray_num = 5;
        const ray_count_f32: f32 = ray_num;

        for (0..ray_num) |i| {
            const i_f32: f32 = @floatFromInt(i);
            const offset: f32 = player.Angle * i_f32 / ray_count_f32;
            const angle: f32 = player.Angle - playerI.FOV / 2.0 + offset;
            _ = ray.cast_ray(player, mapa, angle);
        }
        try fr.Framebuffer.swap_buffers();
    }
}

pub fn render_3D(target: *fr.Framebuffer, map: Map.Mapa, player: playerI.Player) !void {
    const ray_count: usize = @intCast(target.width);
    const ray_count_f32: f32 = @floatFromInt(ray_count);
    const half_screen_height: f32 = @as(f32, @floatFromInt(target.height)) / 2.0;

    const intersect = try .ray.cast_ray(
        target,
        map,
        player,
        angle,
        block_sz,
        false,
    );
    const protection_plane: f32 = 70;
    const draw_height: f32 = half_screen_height / intersect.Distance * protection_plane;

    const bottom: usize = @intFromFloat(half_screen_height - draw_height / 2.0);
    const top: usize = @intFromFloat(half_screen_height + draw_height / 2.0);
    target.set_current_color(switch (intersect.Type) {
        .Corner => .blue,
        .Wall => .red,
        .Green => .green,
    });
    for (bottom..top) |y| {
        try target.set_pixel(@intCast(i), @intCast(y));
    }
}
