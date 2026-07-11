# yosys-sta

Personal fork of [OSCPU/yosys-sta](https://github.com/OSCPU/yosys-sta) — an
ASIC synthesis/timing/power evaluation pipeline built on the open-source synthesizer
[Yosys](https://github.com/YosysHQ/yosys) and NJU's [iEDA](https://github.com/OSCC-Project/iEDA)
toolset (static timing analysis via iSTA, power analysis via iPA).

Used here to turn RTL (from [OSOC](https://github.com/graff1452/OSOC)'s `npc/` designs)
into a real, manufacturable gate-level netlist, and to get a first, logic-delay-only
estimate of a circuit's maximum clock frequency and power consumption.

## Setup

**1. Install Yosys ≥ 0.48** via the prebuilt [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)
(not apt — too old a version there):
```bash
# download the release matching your architecture (check with `uname -m`), then:
tar -xzf oss-cad-suite-linux-*.tgz -C ~/Desktop
echo 'export PATH=$PATH:'"$HOME"'/Desktop/oss-cad-suite/bin' >> ~/.bashrc
source ~/.bashrc
yosys --version
```

**2. Install remaining dependencies, fetch prebuilt iEDA + the PDKs**
```bash
sudo apt-get install libunwind-dev liblzma-dev
make init
echo exit | ./bin/iEDA -v   # should print a version hash
```

## Running synthesis + timing/power analysis

Built-in example (GCD circuit), full pipeline:
```bash
make sta
```
Results land in `result/<design>-<freq>MHz/` — `<design>.netlist.v` is the actual
synthesized netlist; `.rpt`/`.cap`/`.fanout`/`.trans`/`.skew` are iSTA timing reports;
`.pwr`/`_instance.pwr` are iPA power reports. `result/` is gitignored (regenerated
output, not source).

Synthesis only (no timing/power), on your own design:
```bash
make syn DESIGN=<top_module_name> RTL_FILES=/path/to/your.v \
  CLK_PORT_NAME=clk CLK_FREQ_MHZ=500
```
`DESIGN` must match the actual Verilog `module` name, not the filename.

## `counter-test/` — manual, step-by-step synthesis walkthrough

`counter.v` (a simple 2-bit up-counter with sync reset/enable) and a tiny hand-written
`cell.lib` (5 cells: BUF, NOT, NAND, NOR, DFF — deliberately minimal, no delay/power
data, not usable for real STA) — used to walk through every synthesis stage manually,
one Yosys command at a time, watching the circuit's internal structure change at each
step via `show`:

```bash
cd counter-test
yosys counter.v
```
```
hierarchy -check -top counter    # elaboration: parse -> real module
proc                              # procedural (always block) -> $mux/$dff cells
opt                                # coarse-grain optimization (merges into $sdffe)
techmap                           # coarse-grain -> gate-level primitives ($_XOR_, $_NOT_, ...)
splitnets -ports                  # multi-bit signals -> individual 1-bit wires
opt -full
read_liberty -lib cell.lib         # needed before dfflibmap/show for correct pin display
dfflibmap -liberty cell.lib        # map flip-flops to the real DFF cell (adds MUX logic
                                    # for enable/reset, since this tiny DFF has neither)
abc -liberty cell.lib              # map remaining gates to NAND/NOR/NOT (only gates
                                    # this library provides -- everything else gets
                                    # reconstructed from these, since NAND/NOR are
                                    # individually "universal" gates)
clean
show                                # view the diagram after each step above
```

Worth noting from this walkthrough: the `+1` increment logic (`count + 1`) synthesized
down to just one XOR gate and one NOT gate, not a general adder — Yosys recognized that
incrementing by exactly 1 has a simpler bit-pattern (bit0 always flips; bit1 flips only
when bit0 was 1) than general addition needs.

## Running my own designs from `OSOC`

```bash
make syn DESIGN=top \
  RTL_FILES=~/Desktop/OSOC/ysyx-workbench/npc/nvboard-light/vsrc/top.v \
  CLK_PORT_NAME=clk CLK_FREQ_MHZ=500
```
Synthesized the running-light circuit (16-bit `led` + 32-bit `count` registers) to
**190 cells / 566.72 area units** on `icsprout55`, of which **48 are real flip-flops**
(295.68 area, 52% of the total) — matching exactly the 16+32=48 bits of state declared
in the Verilog, a good sanity check that synthesis preserved the design's state
faithfully.
