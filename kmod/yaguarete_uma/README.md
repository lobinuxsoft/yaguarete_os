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

This module implements **method 1 only**, exposed as a read-only sysfs
attribute. Confirmed on hardware: it reports `4096`, matching the 4 GiB
carveout the firmware is configured for.

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

So for a little-endian `uint32 V`, the byte the firmware acts on is
`((V >> 24) & 0xF) << 4 | ((V >> 16) & 0xF)` — the ID lives in the upper half
word, not in the low bits the MOF's `uint32` suggests. That encoding is read off
the ASL and has **not** been confirmed against a real write.

## Building it

`kernel-devel` matching the running kernel is enough; Bazzite ships
`kernel-devel-matched`.

```bash
make
sudo insmod yaguarete_uma.ko
cat /sys/bus/wmi/drivers/yaguarete_uma/*/uma_size
sudo rmmod yaguarete_uma
```

Requires Secure Boot off or the module signed.
