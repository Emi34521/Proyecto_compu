# Proyecto_compu — Ray Caster

Un pequeño juego tipo **Ray Caster**, inspirado en los clásicos shooters en primera persona de los 90 (como Wolfenstein 3D). El objetivo es recorrer un nivel en 3D generado a partir de un mapa 2D, chocando con las paredes lo menos posible y explorando el espacio.

##  Cómo jugar

El juego se puede controlar de dos formas:

### Teclado (WASD)
- **W** — avanzar
- **S** — retroceder
- **A** — girar / moverte a la izquierda
- **D** — girar / moverte a la derecha

### Control (gamepad)
También es compatible con un control conectado, para moverte y rotar la cámara sin usar el teclado.

##  Demostración


[![Video de demostración](https://youtu.be/ZryQyGpcTWQ)]


##  Cómo correrlo

1. Instala [Zig](https://ziglang.org/download/) (asegúrate de tener una versión reciente).
2. Clona este repositorio:
   ```bash
   git clone https://github.com/Emi34521/Proyecto_compu.git
   cd Proyecto_compu
   ```
3. Compila y ejecuta con:
   ```bash
   zig build run
   ```

##  Tecnologías

Hecho en **Zig**.

---
*Proyecto realizado como parte del curso de Gráficas por Computadora.*
