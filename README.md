# VirtIO RISC-V SoC

VirtIO RISC-V SoC (VVSoC) is a general-purpose computer design that trades speed for simplicity and utilizes the VirtIO framework to simplify the implementation of peripheral devices. Although the main goal of the system is to provide a straightforward educational example of an FPGA computer design, it is fully capable of running UNIX-like operating systems and even some sophisticated applications such as Doom.

## Main idea

When designing a computer system from the ground up, one of the most challenging parts is implementing peripheral devices, especially if the devices utilize advanced techniques such as Direct Memory Access (DMA). 

To simplify the design, VVSoC uses the VirtIO-MMIO interface for all peripheral devices and augments the system by adding a small dedicated core that implements the protocol in software. This approach reduces the hardware implementation of each supported VirtIO device to an interface consisting of a set of memory-mapped registers.

The idea is inspired by [RVSoC](https://arxiv.org/abs/2002.03576).

## State of the project

Currently, VVSoC supports the following VirtIO devices:
- VirtIO console device,
- VirtIO keyboard device (via VirtIO input device),
- VirtIO GPU device.

The system can be run in simulation using Verilator or implemented on an FPGA board. At present, the only supported board is the Nexys A7.

To date, two operating systems have been successfully run on VVSoC:
- [Linux](https://github.com/torvalds/linux),
- [Mimiker](https://github.com/cahirwpz/mimiker).

VVSoC can run Doom on Linux, and the game can actually be played.

## Running a simulation

To run Linux in simulation, perform the following steps:
1. Move to the `sim` directory.
2. Run `make`.
3. Run `./obj_dir/Vtop`.

To run Mimiker in simulation, follow the steps below:
1. Move to the `sim` directory.
2. Run `make mimiker_imgs`.
3. Run `make`.
4. Run `./obj_dir/Vtop`.

## Running on FPGA

To run VVSoC on the Nexys A7, perform the following steps:
1. Program the on-board flash with `images/flash/vivado/qspi/linux/fl_hvc.mcs` or `images/flash/vivado/qspi/mimiker/fl.mcs`.
2. Program the FPGA with `images/nexys_a7/vvsoc.bit`.

## License

Copyright © 2026, Michał Błaszczyk.

This project is licensed under the [BSD 3-Clause](https://github.com/MichalBlk/vvsoc/blob/readme/LICENSE) License.
