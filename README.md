# FUNNY USELESS THING

## requirements
- `qemu-system-x86_64`
- `zig` compiler 0.11.0
- UEFI firmware (edk2 OVMF firmware is provided)

## build instructions
- `make` to build
- `make run` to run

## bugs
- building in debug mode breaks the application
- we never free anything (I hope you have a large amount of ram :D)
