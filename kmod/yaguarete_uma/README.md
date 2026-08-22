# `yaguarete_uma` — read the firmware's UMA frame buffer size

Not built by the image. Source lives here so the work is not stranded in a
scratch directory while the write path is still undecided (#267).

## What it is

The ONEXPLAYER F1 Pro firmware ships an ACPI-WMI class called `UMAInterface`.
It is not documented anywhere; the schema below came out of the device's own
BMOF blob, decoded with [`pali/bmfdec`](https://github.com/pali/bmfdec):

```mof
[WMI, Dynamic, Provider("WmiProv"), Description("SetUmaWmi"),
 guid("{1f72b0f1-bfea-4472-9877-6e62937ab616}")]
class UMAInterface : CustomUmaMode {
  [WmiMethodId(1)] GetUMASize   ([out] uint32 Data);
  [WmiMethodId(2)] SetUMAsize   ([in]  uint32 UmaSizeID, [out] uint8 ResultStatus);
  [WmiMethodId(3)] GetCmosValue ([in]  uint32 Index,     [out] uint8  Data);
  [WmiMethodId(4)] SetCmosValue ([in]  uint32 Index,     [out] uint8  Data);
  [WmiMethodId(5)] GetEcValue   ([in]  uint32 Index,     [out] uint8  Data);
  [WmiMethodId(6)] SetEcValue   ([in]  uint32 Index,     [out] uint8  Data);
  [WmiMethodId(7)] GetMemValue  ([in]  uint32 Index,     [out] uint32 Data);
  [WmiMethodId(8)] SetMemValue  ([in]  uint64 Index,     [out] uint32 Result);
};
```

The module implements **methods 1 and 2**: `uma_size` reads the current size in
MiB and, when the module is loaded with `allow_write=1`, sets a new one.
Confirmed on hardware: the read reports `4096`, matching the 4 GiB carveout the
firmware is configured for.

## The size is an index, and the table is the vendor's

`SetUMAsize` does not take a size. It takes a `UmaSizeID`, and nothing in the
BMOF says what the IDs mean. Rather than guess, the table comes out of
OneXConsole's own `background.js`:

```js
i = {1:4, 2:8, 3:16, 4:32, 5:64, 6:96};
if (r >= 64) i = {1:4, 2:8, 3:16, 4:32, 5:64, 6:128, 7:192};
if (4*r <= n) break;          // r = RAM in GB, n = table value
```

Values are quarter-gigabytes, so `n/4` is the size in GB:

| ID | Size | ID | Size |
|---|---|---|---|
| 1 | 1 GB | 5 | 16 GB |
| 2 | 2 GB | 6 | 24 GB — **32 GB if RAM >= 64** |
| 3 | 4 GB | 7 | 48 GB — only if RAM >= 64 |
| 4 | 8 GB | | |

The last rule matters: an ID is only offered while its size is strictly smaller
than total RAM. `uma_available` prints exactly what this machine may be set to.

**The RAM figure is physical, not usable.** OneXConsole asks Windows for
physical memory; `totalram_pages()` reports what survived firmware
reservations, which on this unit is 58 GiB of a 64 GiB machine. The driver
rounds up to the next 8 GiB to recover the number the table was written
against. Getting that wrong selects the other table, where ID 6 means 24 GB
instead of 32.

## Why the read is safe and the write is not

From the DSDT's `WMBB`, the two paths could not be more different.

`GetUMASize` returns a 32-bit field out of the CPM NV region. No SMI, no write,
no side effect:

```asl
If ((Arg1 == One)) { Return (M233) }
```

`SetUMAsize` packs two nibbles out of the input buffer and triggers a **system
management interrupt**, which hands control to firmware that writes NVRAM:

```asl
If ((Arg1 == 0x02))
{
    CreateByteField (Arg2, 0x02, M23F)
    CreateByteField (Arg2, 0x03, M240)
    Local0 = ((M240 & 0x0F) << 0x04)
    Local0 |= (M23F & 0x0F)
    M232 (M23A, Local0, One)      // M232 == CpmTriggerSmi(cmd, data, delay)
    Return (Local0)
}
```

For a little-endian `u32` the ID therefore lives in the upper half word, split
across the low nibbles of bytes 2 and 3. That split is not decoration: the
non-370 platform indexes up to 128, which does not fit in one nibble.

The ASL returns `Local0` — the packed byte it acted on — even though the schema
calls the out parameter `ResultStatus`. The driver treats a returned value
different from what it sent as a failure.

## Before you write anything

**The change takes effect on the next boot, and it is firmware state.** It does
not live in the deployment, so no `bootc rollback`, no `ostree` pin and no
reinstall touches it. Plan the way back before the way in:

- **Only the vendor's sizes are accepted.** Anything not in `uma_available` is
  rejected with `-EINVAL` rather than sent to firmware.
- **Set it back the same way.** The interface is symmetric: write the old size
  and reboot. `4096` is this unit's factory value.
- **If the machine will not display after a reboot**, the fallback is the
  firmware setup itself (the knob exists there as
  `CbsCmnGnbGfxUmaFrameBufferSize` in the `AmdSetup` variable store), or
  OneXConsole on Windows, which drives this same interface.
- **A large carveout costs system RAM permanently** until it is changed back.
  It is not shared like GTT: the firmware hands that slice to the iGPU and the
  OS never sees it.
- **Consider whether you need it at all.** Kernel 7.2 brought VRAM overcommit
  with `dmem` cgroups, and on a unified-memory APU the GTT already spills into
  the same DDR at the same bandwidth — `ujust yaguarete-vram` moves that ceiling
  with no firmware involved. What a bigger carveout buys is a bigger number
  *reported* as VRAM, which matters to software that queries it and refuses or
  degrades on what it sees.

## Building it

`kernel-devel` matching the running kernel is enough; Bazzite ships
`kernel-devel-matched`. Secure Boot must be off, or the module signed.

```bash
make
sudo insmod yaguarete_uma.ko                 # read-only
sudo insmod yaguarete_uma.ko allow_write=1   # read and write

cd /sys/bus/wmi/drivers/yaguarete_uma/*/
cat uma_size        # 4096
cat uma_available   # e.g. 1024 2048 4096 8192 16384 32768 49152
echo 8192 | sudo tee uma_size   # staged; reboot to apply
```

**No write has been performed yet.** The encoding, the table and the return
convention are all read out of the firmware and the vendor's own application;
none of it has been confirmed against a machine that actually rebooted.
