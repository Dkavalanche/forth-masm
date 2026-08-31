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
   - Utilidades: . .s clear words quit
   - Memoria: constant variable @ !
   - Saltos internos: 0branch branch
   - Condicionales: if else then
   - Ciclos: begin until again while repeat
   - Salida anticipada de palabras compiladas: exit

 Cambios recientes:
   - Se valida la correspondencia entre if/else/then y los ciclos
   - Una definición inválida se descarta sin alterar el diccionario

 Notas:
   - Las palabras de control se ejecutan durante la compilación
   - Las direcciones de salto compiladas son absolutas
   - while debe utilizarse después de begin
   - repeat debe cerrar la estructura begin ... while ... repeat
   - again crea un ciclo infinito salvo que se use exit
   - clear vacía solamente la pila de datos
   - Una línea con error no imprime OK

 Próxima etapa prevista:
   - Agregar ciclos contados: do loop +loop i
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

Ejemplo usando `ml.exe` y `link.exe`:

```bat
ml.exe /c /Cp /coff src\forth_entrega.asm
link /SUBSYSTEM:console /DEFAULTLIB:kernel32.lib forth_entrega.obj /ENTRY:main
```

## Licencia

Este proyecto se distribuye bajo **GNU GPL v3.0**. Ver el archivo [LICENSE](LICENSE).
