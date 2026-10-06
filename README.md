# Forth MASM x86 (Windows 32-bit)

Proyecto de un intérprete **Forth** para **Windows x86 de 32 bits**, desarrollado en **MASM moderno** con foco en aprendizaje de assembler, diseño de intérpretes y arquitectura tipo stack machine.

## Estado actual

 Incluye:
   - Consola interactiva y parser por tokens
   - Normalización del input a minúsculas
   - Diccionario estático y definiciones dinámicas con : y ;
   - Stack de datos y literales compilados mediante lit
   - Aritmética: + - * /
   - Comparaciones: = < > 0= 0< 0>
   - Stack: dup drop swap over depth
   - Return stack: >r r> r@
   - Validación de underflow y división por cero
   - Validación de estructuras de control durante la compilación
   - Primitivas internas protegidas: lit, 0branch y branch
   - Ciclos contados: do loop +loop i j k
   - Utilidades: . .s clear words quit
   - Memoria: constant variable @ !
   - Saltos internos: 0branch branch
   - Condicionales: if else then
   - Ciclos: begin until again while repeat
   - Salida anticipada de palabras compiladas: exit

 Cambios recientes:
   - Se agregó +loop con incrementos variables positivos y negativos
   - Pruebas automáticas de ciclos, errores y regresiones sobre el ejecutable

 Notas:
   - Las palabras de control se ejecutan durante la compilación
   - Las direcciones de salto compiladas son absolutas
   - while debe utilizarse después de begin
   - repeat debe cerrar la estructura begin ... while ... repeat
   - again crea un ciclo infinito salvo que se use exit
   - clear vacía solamente la pila de datos
   - Una línea con error no imprime OK
   - Los números dentro de : ... ; generan lit automáticamente
   - do usa el orden ( límite inicio -- )
   - do ... loop conserva el límite exclusivo y omite el cuerpo si inicio >= límite
   - do ... +loop entra siempre al cuerpo; termina al cruzar la frontera entre límite-1 y límite

 Próxima etapa prevista:
   - Agregar palabras de stack: rot nip tuck 2dup 2drop
## Ejemplos

### Aritmética básica

```forth
10 20 + .
```

Resultado esperado:

```text
30
```

### Definición de palabras

```forth
: doble dup + ;
5 doble .
```

Resultado esperado:

```text
10
```

### Inspección del stack

```forth
1 2 3 .s
```

Resultado esperado:

```text
[ 1 2 3 ]
```

### Return stack

```forth
10 >r
r@ .
r> .
```

Resultado esperado:

```text
10
10
```

### Ciclo de 1 a 10

```forth
: contar-1-a-10
  0
  begin
    dup 10 < while
    1 + dup .
  repeat
  drop
;

contar-1-a-10
```

Salida esperada:

```text
1
2
3
4
5
6
7
8
9
10
```

### Ciclo contado

```forth
: contar-con-i
  10 0 do
    i .
  loop
;

contar-con-i
```

Salida esperada:

```text
0
1
2
3
4
5
6
7
8
9
```

### Ciclos con incremento variable

`+loop` consume un incremento de la pila en cada iteración: `( incremento -- )`.
El incremento puede calcularse dentro del cuerpo.

```forth
: pares 10 0 do i . 2 +loop ;
pares
```

Imprime `0 2 4 6 8`, un número por línea. Un paso de `3` imprime `0 3 6 9`:
no hace falta alcanzar exactamente el límite.

```forth
: bajar 0 6 do i . -2 +loop ;
bajar
```

Imprime `6 4 2 0`. En descenso, alcanzar el límite no termina el ciclo:
debe cruzarse la frontera hacia `límite-1`, según la semántica de
[`+LOOP` en Forth](https://forth-standard.org/standard/core/PlusLOOP).
Los cálculos son circulares de 32 bits y detectan el cruce incluso con desbordamiento.

Por compatibilidad con este proyecto, el compilador distingue ambos cierres:
`do ... loop` sigue omitiendo el cuerpo cuando `inicio >= límite`, mientras que
`do ... +loop` entra siempre, incluso si ambos valores son iguales.
Por eso reemplazar `loop` por `1 +loop` no es equivalente en esos casos.

Un incremento cero repite el mismo índice; un paso que se aleja del límite puede
dar un ciclo muy largo. Se puede terminar con `exit`, que libera los ciclos de
la palabra actual. No se agrega `leave` en esta versión.

`+loop` requiere un `do` pendiente y estructuras interiores cerradas. Si falta
el incremento en ejecución, informa `Stack underflow` y sale de la palabra actual.
Los runtimes `(do)`, `(loop)`, `(+do)` y `(+loop)` son internos y están protegidos.

### Ciclos anidados

```forth
: indices-anidados
  2 0 do
    2 0 do
      i .
      j .
    loop
  loop
;

indices-anidados
```

Salida esperada:

```text
0
0
1
0
0
1
1
1
```

`i` corresponde al loop más interno, `j` al siguiente exterior y `k` al tercero. Usar `j` o `k` sin suficientes loops activos muestra `Loop context error`.

### Errores de ejecución

```forth
+
10 0 /
```

Salida esperada:

```text
Stack underflow
Division by zero
```

### Primitivas internas

`lit`, `0branch` y `branch` son detalles internos del código compilado. No se muestran con `words` ni se escriben directamente en la consola o dentro de `: ... ;`.

Los literales se escriben normalmente:

```forth
: respuesta 42 ;
respuesta .
```

Resultado esperado:

```text
42
```

### Errores de compilación

```forth
: sin-cierre if 10 ;
: ciclo-invalido begin 1 ;
: else-suelto else 5 ;
```

Cada línea debe informar:

```text
Control structure error
```

Las palabras `sin-cierre`, `ciclo-invalido` y `else-suelto` no deben aparecer en `words`.

## Estructura del proyecto

```text
forth-masm/
│
├─ src/
│  ├─ forth.asm
│  └─ versiones/
│
├─ docs/
│
├─ build/
├─ backup/
├─ .gitignore
├─ README.md
├─ roadmap.md
├─ cambios.md
└─ LICENSE
```

## Compilación

Desde una consola de herramientas x86 de Visual Studio, usando `ml.exe` y `link.exe`:

```bat
if not exist build mkdir build
ml.exe /c /Cp /coff /Fo build\forth.obj src\forth.asm
link.exe /SUBSYSTEM:console /DEFAULTLIB:kernel32.lib build\forth.obj /OUT:build\forth.exe
```

## Pruebas automáticas

Después de compilar la versión actual como `build\forth.exe`, ejecutar en Windows
con Python 3 (sin dependencias externas):

```powershell
python tests/test_cycles.py
```

También se puede indicar otra ruta al ejecutable como primer argumento.
El runner abre consolas ocultas, envía comandos al intérprete real y verifica
la salida con un tiempo máximo por comando. No utiliza redirección de entrada,
porque el intérprete usa `ReadConsoleA` y `WriteConsoleA`.

Las 36 pruebas cubren pasos positivos, negativos, variables y cero, límites
iguales, cruces y desbordamientos de 32 bits, anidamiento con `i/j/k`, return stack,
`exit`, underflow, errores de compilación, rollback del diccionario y regresiones
de las palabras existentes. Ver [tests/test_cycles.py](tests/test_cycles.py).

## Licencia

Este proyecto se distribuye bajo **GNU GPL v3.0**. Ver el archivo [LICENSE](LICENSE).
