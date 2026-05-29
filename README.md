# Forth MASM x86 (Windows 32-bit)

Proyecto de un intérprete **Forth** para **Windows x86 de 32 bits**, desarrollado en **MASM moderno** con foco en aprendizaje de assembler, diseño de intérpretes y arquitectura tipo stack machine.

## Estado actual

La versión actual ya implementa:

- consola interactiva
- parser por tokens
- normalización de input a minúsculas
- stack de datos
- diccionario estático
- diccionario dinámico mínimo
- definiciones de palabras con `:` y `;`
- soporte de literales compilados (`lit`)
- ejecución de palabras compiladas (`do_colon`)
- aritmética:
  - `+`
  - `-`
  - `*`
  - `/`
- comparaciones:
  - `=`
  - `<`
  - `>`
  - `0=`
  - `0<`
  - `0>`
- palabras de stack:
  - `dup`
  - `drop`
  - `swap`
  - `over`
  - `depth`
- utilidades:
  - `.`
  - `.s`
  - `clear`
  - `words`
  - `quit`
- manejo básico de error con `?`

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

## Roadmap

### Completado
- stack de datos
- parser por tokens
- diccionario estático
- definiciones con `:` y `;`
- `lit`
- `do_colon`
- aritmética, comparaciones y palabras básicas de stack
- `.s` pulido
- `depth`
- `0=`, `0<`, `0>`

### Próximo bloque
- `constant`
- `variable`
- `@`
- `!`

### Más adelante
- `if else then`
- `begin until again`
- `>r r> r@`
- memoria más completa
- port limpio a x64

## Objetivo del proyecto

Construir primero un **Forth serio en 32 bits** como base estable y didáctica.  
Una vez consolidada la arquitectura, realizar un **port limpio a 64 bits** como segunda etapa del proyecto.

## Licencia

Este proyecto se distribuye bajo **GNU GPL v3.0**. Ver el archivo [LICENSE](LICENSE).
