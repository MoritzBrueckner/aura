# Aura Backends

The `/Backends` directory contains target-specific code that may be used on some
targets to improve performance.

The backends are enabled by default, but if you want to only use the generic
Haxe sources (for performance comparisons e.g.), compile your Kha project with
the command line flag `--aura-no-backend`.

## Folder Structure

- `/common_c`:
  Pure C code that can be used by multiple backends.

- `/hl`:
  Sources/headers for the Hashlink/C backend. The header files are mostly
  Hashlink API wrappers around the code in `/common_c`.

Most of the backend sources mirror the respective Haxe code, so please don't
expect much documentation for the individual functions.

The Haxe implementation/glue code for the backends is in Aura's source files in
`/Sources`. There are no Haxe files in the `/backend` folder that shadow
original sources to reduce redundancy and ensure completeness of the API.

Instead, there is usually a static class per backend implementation at the
bottom of a Haxe source module, whose methods are then called and inlined from
the original class if the [backend specific define is set](#defines). This way
all the Haxe functionality for a module stays inside a module and is not
distributed in many per-backend Haxe files, which also keeps the API consistent
for each target.

## Defines

If the backends are enabled, Aura sets some defines before compilation which are
based on the Haxe target to which the project is compiled. They should only be
used internally, but for the sake of completeness they are documented here:

- `AURA_NO_BACKEND`: Defined if backends are disabled.
- `AURA_BACKEND_HL`: Defined if backends are enabled and the project is compiled
  to a Hashlink target.
