const std = @import("std");

pub fn main(init: std.process.Init) !void {
    //Básicamente se carga primero el mapa del juego y se imprime en consola.
    var mapa = try Mapa.load_map(init.io, init.gpa, "src/resources/mapa.txt");
    defer mapa.deinit(init.gpa);
    for (mapa.cells) |linea| {
        std.debug.print("{s}", .{linea});
    }
}

//struct para cargar el mapa del juego
const Mapa = struct {
    cells: [][]u8,

    fn load_map(io: std.Io, gpa: std.mem.Allocator, filename: []const u8) !Mapa {
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
    fn deinit(self: *Mapa, gpa: std.mem.Allocator) void {
        for (self.cells) |linea| {
            gpa.free(linea);
        }
        gpa.free(self.cells);
    }
};
