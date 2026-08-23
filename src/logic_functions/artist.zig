// Funciones de dibujo simple sobre el framebuffer.
const fr = @import("framebuffer.zig");

// Dibuja un cuadrado relleno usando el color actual del framebuffer
// (el que se fija con target.set_current_color(...)).
pub fn square(target: *fr.Framebuffer, x: i32, y: i32, w: usize, h: usize) void {
    const x_f32: f32 = @floatFromInt(x);
    const y_f32: f32 = @floatFromInt(y);

    for (0..h) |dy| {
        for (0..w) |dx| {
            const dx_f32: f32 = @floatFromInt(dx);
            const dy_f32: f32 = @floatFromInt(dy);
            target.draw_pixel(x_f32 + dx_f32, y_f32 + dy_f32, target.current_color) catch continue;
        }
    }
}
