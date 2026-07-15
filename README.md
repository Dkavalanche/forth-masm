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
   - Utilidades: . .s clear words quit
   - Memoria: constant variable @ !
   - Saltos internos: 0branch branch
   - Condicionales: if else then
   - Ciclos: begin until again while repeat
   - Salida anticipada de palabras compiladas: exit

 Cambios recientes:
   - Agregadas las palabras de compilación while y repeat
   - while compila un salto condicional de salida pendiente
   - repeat compila el salto hacia begin y resuelve la salida
   - Se conserva la corrección del enlace de constant y variable

 Notas:
   - Las palabras de control se ejecutan durante la compilación
   - Las direcciones de salto compiladas son absolutas
   - while debe utilizarse después de begin
   - repeat debe cerrar la estructura begin ... while ... repeat
   - again crea un ciclo infinito salvo que se use exit

 Próxima etapa prevista:
   - Mejorar la validación de estructuras de control incompletas
   - Agregar más palabras de stack o un return stack
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
