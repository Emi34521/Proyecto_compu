const std = @import("std");
const fr = @import("logic_functions/framebuffer.zig");
const artist = @import("artist.zig");
const rl = @import("raylib");

//struct para cargar el mapa del juego
pub const Mapa = struct {
    cells: [][]u8,

    pub fn load_map(io: std.Io, gpa: std.mem.Allocator, filename: []const u8) !Mapa {
        var cwd = std.Io.Dir.cwd();
        defer cwd.close(io);

        var fd = try cwd.openFile(io, filename, .{});
        defer fd.close(io);

        var buffer: [1024]u8 = undefined;
        var file_reader = fd.reader(io, &buffer);
        const reader = &file_reader.interface;

        var out: std.ArrayList([]u8) = .empty;

        errdefer out.deinit(gpa); // por si algo falla a medio camino
        while (reader.takeDelimiterInclusive('\n')) |datos| {
            const espacio_copia = try gpa.alloc(u8, datos.len);
            @memcpy(espacio_copia, datos);
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
                    '+' => target.set_current_color(rl.blue),
                    '-' => target.set_current_color(rl.red),
                    '|' => target.set_current_color(rl.blue),
                    ' ' => continue,
                    else => {
                        std.log.err("Map cells not supported", .{cell});
                    },
                }
                artist.square(target, @intCast(x), @intCast(y), block_sz, block_sz);
            }
        }
    }
};
