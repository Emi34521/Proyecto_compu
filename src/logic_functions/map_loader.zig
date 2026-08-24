const std = @import("std");
const fr = @import("framebuffer.zig");
const artist = @import("artist.zig");
const rl = @import("raylib");

//struct para cargar el mapa del juego
pub const Mapa = struct {
    cells: [][]u8,

    pub fn load_map(io: std.Io, gpa: std.mem.Allocator, filename: []const u8) !Mapa {
        var cwd = std.Io.Dir.cwd();
        //defer cwd.close(io); para gargar las texturas del mapa, es mucho mejor comentar esto.

        var fd = try cwd.openFile(io, filename, .{});
        defer fd.close(io);

        var buffer: [1024]u8 = undefined;
        var file_reader = fd.reader(io, &buffer);
        const reader = &file_reader.interface;

        var out: std.ArrayList([]u8) = .empty;

        errdefer out.deinit(gpa); // por si algo falla a medio camino
        while (reader.takeDelimiterInclusive('\n')) |datos| {
            // quitamos \r y \n del final, si no cada fila queda con una
            // "pared fantasma" invisible al final por esos caracteres
            const linea_limpia = std.mem.trimEnd(u8, datos, "\r\n");
            if (linea_limpia.len == 0) continue; // ignora líneas vacías

            const espacio_copia = try gpa.alloc(u8, linea_limpia.len);
            @memcpy(espacio_copia, linea_limpia);
            try out.append(gpa, espacio_copia);
        } else |err| switch (err) {
            error.EndOfStream => {},
            error.ReadFailed => return err,
            error.StreamTooLong => return err,
        }
        return .{ .cells = try out.toOwnedSlice(gpa) };
    }
    pub fn deinit(self: *Mapa, gpa: std.mem.Allocator) void {
        for (self.cells) |linea| {
            gpa.free(linea);
        }
        gpa.free(self.cells);
    }
    pub fn render(map: Mapa, target: *fr.Framebuffer, block_sz: usize) void {
        for (map.cells, 0..) |row, row_idx| {
            for (row, 0..) |cell, col_idx| {
                const x = col_idx * block_sz;
                const y = row_idx * block_sz;

                switch (cell) {
                    '+' => target.set_current_color(rl.Color.blue),
                    '-' => target.set_current_color(rl.Color.red),
                    '|' => target.set_current_color(rl.Color.blue),
                    ' ' => continue,
                    else => {
                        std.log.err("Celda de mapa no soportada: {c}", .{cell});
                        continue;
                    },
                }
                artist.square(target, @intCast(x), @intCast(y), block_sz, block_sz);
            }
        }
    }
    //función que indica que algo es una pared o no. Retorna un bool
    pub fn isWall(self: Mapa, x: f32, y: f32, block_sz: f32) bool {
        if (x < 0 or y < 0) return true;
        const i: usize = @intFromFloat(x / block_sz);
        const j: usize = @intFromFloat(y / block_sz);
        if (j >= self.cells.len or i >= self.cells[j].len) return true;
        return self.cells[j][i] != ' ';
    }
};
