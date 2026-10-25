# Roadmap del proyecto

## Completado
- stack de datos
- parser por tokens
- diccionario estático
- palabras básicas
- `.`, `.s`, `clear`, `words`, `quit`
- `: ;`
- `lit`
- `do_colon`
- `depth`
- `0=`, `0<`, `0>`

## Completado desde la primera etapa
- `constant`
- `variable`
- `@`
- `!`
- `if else then`
- `begin until again while repeat`
- `>r r> r@`
- `exit`
- Validación de estructuras de control y rollback de definiciones inválidas
- Protección de primitivas internas
- `do loop i j k`
- `+loop`: incrementos variables y cruces del límite en 32 bits
- Pruebas automáticas de ciclos y regresiones sobre la consola Win32

## Próximo bloque
- Carga y ejecución de archivos: `forth.exe -f codigo.f`
- Procesar líneas conservando el estado de compilación y los comentarios multilínea
- Informar errores con archivo y número de línea

## Completado recientemente
- Palabras de pila: `rot nip tuck 2dup 2drop`
- Comentarios `( ... )` y `\` hasta fin de línea

## Más adelante
- Literales de cadena
- Validar límites de capacidad de las pilas
- memoria más completa
- port a x64
