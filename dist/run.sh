#!/bin/sh

qemu-system-x86_64 -drive file=fat:rw:./uefi,format=raw -machine q35,smm=on,accel=kvm -pflash uefi/OVMF.fd