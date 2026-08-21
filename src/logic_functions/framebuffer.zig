//framebuffer para que raylib lea el framebuffer y pueda dibujar en la pantalla
//librería de raylib
const rl = @import("raylib");
//estructura de un punto en el framebuffer
pub const Point = struct {
    x: f32,
    y: f32,
};

//estructura del framebuffer
pub const Framebuffer = struct {
    // Resolución interna del framebuffer (la resolución del juego).
    width: i32,
    height: i32,

    // Resolución de la ventana real donde se presenta el framebuffer ya
    // escalado. Puede ser más grande que width/height.
    window_width: i32,
    window_height: i32,

    // La imagen que representa el framebuffer. Cada pixel de la imagen es un pixel del framebuffer.
    image: rl.Image,
    texture: ?rl.Texture,
    background_color: rl.Color,

    // Inicializa un framebuffer con la resolución interna y de ventana dadas, y con un color de fondo.
    pub fn init(width: i32, height: i32, window_width: i32, window_height: i32, color: rl.Color) Framebuffer {
        return Framebuffer{
            .width = width,
            .height = height,
            .window_width = window_width,
            .window_height = window_height,
            .image = rl.genImageColor(width, height, color),
            .background_color = color,
            .texture = null,
        };
    }

    /// La función point pinta un solo pixel del framebuffer de un color.
    pub fn point(self: *Framebuffer, x: i32, y: i32, color: rl.Color) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;
        self.image.drawPixel(x, y, color);
    }

    /// Limpia el framebuffer con el color de fondo.
    pub fn clear(self: *Framebuffer) void {
        self.image.clearBackground(self.background_color);
    }
};
