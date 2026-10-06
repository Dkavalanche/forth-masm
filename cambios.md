# Cambios del proyecto

## 2026-10-06 — Ciclos con incremento variable
- Se agregó `+loop`, que consume el incremento en cada iteración.
- Soporta pasos positivos y negativos y detecta cruces del límite con aritmética circular de 32 bits.
- `do ... +loop` entra siempre al cuerpo; en descenso puede incluir el índice igual al límite.
- Se preservó la omisión de rangos con inicio >= límite en `do ... loop`.
- El compilador valida el cierre de `do` y protege los nuevos runtimes internos.
- Se agregaron 36 pruebas automáticas de consola: ciclos, anidamiento, errores, diccionario y regresiones.
- Se actualizaron README, roadmap y cabecera del fuente.

## Funciones incorporadas desde v0.6 hasta esta iteración
- Constantes, variables y acceso a memoria: `constant variable @ !`.
- Condicionales y ciclos: `if else then begin until again while repeat`.
- Return stack: `>r r> r@`; salida anticipada: `exit`.
- Validación de estructuras de control y descarte de definiciones inválidas.
- Protección de primitivas internas del compilador.
- Ciclos contados `do loop` e índices anidados `i j k`.

## v0.1
- loop interactivo base
- stack y parser numérico

## v0.2
- palabras `+`, `.`, `.s`, `dup`, `drop`

## v0.3
- `swap`, `over`, `clear`, `words`

## v0.4
- comparaciones `= < >`
- `0= 0< 0>`

## v0.5
- soporte mínimo de `:` y `;`
- `lit`
- `do_colon`

## v0.6
- `.s` mejorado
- `depth`
