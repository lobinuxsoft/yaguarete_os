// SPDX-License-Identifier: GPL-2.0-only
/*
 * WMI driver for the OneXPlayer UMA frame buffer interface.
 *
 * The firmware ships an ACPI-WMI class named UMAInterface, described by the
 * device's own BMOF blob. Method 1 (GetUMASize) reads a 32-bit field out of
 * the CPM NV region and triggers nothing. Method 2 (SetUMAsize) hands a packed
 * byte to an SMI, and firmware writes NVRAM from there.
 *
 * The size is not passed as a size. It is an index into a table that belongs
 * to the vendor, recovered from OneXConsole's own background.js rather than
 * guessed:
 *
 *	i = {1:4, 2:8, 3:16, 4:32, 5:64, 6:96};
 *	if (r >= 64) i = {1:4, 2:8, 3:16, 4:32, 5:64, 6:128, 7:192};
 *	if (4*r <= n) break;		// r = RAM in GB, n = table value
 *
 * Values are quarter-gigabytes, so n/4 is the size in GB and the largest
 * offered index is the last one strictly smaller than total RAM.
 */

#include <linux/acpi.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/sysfs.h>
#include <linux/wmi.h>

#define UMA_GUID "1F72B0F1-BFEA-4472-9877-6E62937AB616"

/* WmiMethodId values, straight from the UMAInterface schema. */
#define UMA_GET_SIZE 1
#define UMA_SET_SIZE 2

/*
 * Writing changes a firmware setting that only takes effect after a reboot and
 * cannot be undone from a booted system if it leaves the iGPU unable to come
 * up. Off unless asked for.
 */
static bool allow_write;
module_param(allow_write, bool, 0444);
MODULE_PARM_DESC(allow_write, "Permit SetUMAsize, which writes firmware NVRAM");

/* Quarter-gigabytes, indexed by UmaSizeID. Slot 0 is unused by the vendor. */
static const u16 sizes_small[] = { 0, 4, 8, 16, 32, 64, 96 };
static const u16 sizes_large[] = { 0, 4, 8, 16, 32, 64, 128, 192 };

struct uma_table {
	const u16 *values;
	size_t count;
	unsigned int ram_gb;
};

static void build_table(struct uma_table *t)
{
	u64 bytes = (u64)totalram_pages() << PAGE_SHIFT;

	/*
	 * The vendor asks Windows for *physical* memory; totalram_pages() is
	 * what survived firmware reservations, and on this unit reports 58 GiB
	 * of a 64 GiB machine. Rounding up to the next 8 GiB recovers the
	 * number the table was written against -- getting this wrong picks the
	 * other table, where index 6 means 24 GB instead of 32.
	 */
	t->ram_gb = round_up(bytes, 8ULL << 30) >> 30;

	if (t->ram_gb >= 64) {
		t->values = sizes_large;
		t->count = ARRAY_SIZE(sizes_large);
	} else {
		t->values = sizes_small;
		t->count = ARRAY_SIZE(sizes_small);
	}
}

/* MiB for an index, or 0 if the index is out of range or too big for this RAM. */
static u32 size_of(const struct uma_table *t, u8 index)
{
	if (index == 0 || index >= t->count)
		return 0;
	/* The vendor stops offering an index once its size reaches total RAM. */
	if (t->values[index] >= 4 * t->ram_gb)
		return 0;
	return (u32)t->values[index] * 256;
}

static int read_size(struct wmi_device *wdev, u32 *size)
{
	struct acpi_buffer out = { ACPI_ALLOCATE_BUFFER, NULL };
	u32 unused = 0;
	struct acpi_buffer in = { sizeof(unused), &unused };
	union acpi_object *obj;
	acpi_status status;
	int ret = 0;

	status = wmidev_evaluate_method(wdev, 0x0, UMA_GET_SIZE, &in, &out);
	if (ACPI_FAILURE(status))
		return -EIO;

	obj = out.pointer;
	if (!obj)
		return -ENODATA;

	if (obj->type != ACPI_TYPE_INTEGER)
		ret = -EPROTO;
	else
		*size = (u32)obj->integer.value;

	kfree(obj);
	return ret;
}

static int write_index(struct wmi_device *wdev, u8 index)
{
	struct acpi_buffer out = { ACPI_ALLOCATE_BUFFER, NULL };
	union acpi_object *obj;
	acpi_status status;
	u32 arg;
	int ret = 0;

	/*
	 * The ASL takes the low nibble of bytes 2 and 3 and packs them:
	 *
	 *	Local0 = ((M240 & 0x0F) << 0x04) | (M23F & 0x0F)
	 *
	 * where M23F is byte 2 and M240 is byte 3. For a little-endian u32
	 * that puts the ID in the upper half word, split across two nibbles --
	 * which is how the other platform's indices, up to 128, fit at all.
	 */
	arg = ((u32)((index >> 4) & 0xF) << 24) | ((u32)(index & 0xF) << 16);

	{
		struct acpi_buffer in = { sizeof(arg), &arg };

		status = wmidev_evaluate_method(wdev, 0x0, UMA_SET_SIZE, &in, &out);
	}
	if (ACPI_FAILURE(status))
		return -EIO;

	obj = out.pointer;
	if (!obj)
		return -ENODATA;

	/*
	 * The schema calls this ResultStatus, but the ASL returns Local0 --
	 * the packed byte it just acted on. Anything else means firmware did
	 * not take the value we sent.
	 */
	if (obj->type != ACPI_TYPE_INTEGER)
		ret = -EPROTO;
	else if ((u8)obj->integer.value != index)
		ret = -EIO;

	kfree(obj);
	return ret;
}

static ssize_t uma_size_show(struct device *dev, struct device_attribute *attr,
			     char *buf)
{
	u32 size;
	int ret;

	ret = read_size(to_wmi_device(dev), &size);
	if (ret)
		return ret;

	return sysfs_emit(buf, "%u\n", size);
}

static ssize_t uma_size_store(struct device *dev, struct device_attribute *attr,
			      const char *buf, size_t count)
{
	struct uma_table t;
	unsigned int want;
	u8 index;
	int ret;

	if (!allow_write)
		return -EPERM;

	ret = kstrtouint(buf, 10, &want);
	if (ret)
		return ret;

	build_table(&t);
	for (index = 1; index < t.count; index++)
		if (size_of(&t, index) == want)
			break;

	/* Only the vendor's own sizes; anything else is a value never tested. */
	if (index >= t.count)
		return -EINVAL;

	ret = write_index(to_wmi_device(dev), index);
	if (ret)
		return ret;

	dev_info(dev, "staged %u MiB (UmaSizeID %u); takes effect on reboot\n",
		 want, index);
	return count;
}
static DEVICE_ATTR_RW(uma_size);

static ssize_t uma_available_show(struct device *dev,
				  struct device_attribute *attr, char *buf)
{
	struct uma_table t;
	int len = 0;
	u8 i;

	build_table(&t);
	for (i = 1; i < t.count; i++) {
		u32 mib = size_of(&t, i);

		if (mib)
			len += sysfs_emit_at(buf, len, "%u ", mib);
	}

	return len + sysfs_emit_at(buf, len, "\n");
}
static DEVICE_ATTR_RO(uma_available);

static struct attribute *uma_attrs[] = {
	&dev_attr_uma_size.attr,
	&dev_attr_uma_available.attr,
	NULL
};
ATTRIBUTE_GROUPS(uma);

static int uma_probe(struct wmi_device *wdev, const void *context)
{
	struct uma_table t;
	u32 size;
	int ret;

	build_table(&t);
	ret = read_size(wdev, &size);
	if (ret)
		dev_warn(&wdev->dev, "GetUMASize failed: %d\n", ret);
	else
		dev_info(&wdev->dev, "GetUMASize reports %u MiB, %u GB RAM, writes %s\n",
			 size, t.ram_gb, allow_write ? "enabled" : "disabled");

	return 0;
}

static const struct wmi_device_id uma_id_table[] = {
	{ UMA_GUID, NULL },
	{ }
};
MODULE_DEVICE_TABLE(wmi, uma_id_table);

static struct wmi_driver uma_driver = {
	.driver = {
		.name = "yaguarete_uma",
		.dev_groups = uma_groups,
	},
	.id_table = uma_id_table,
	.probe = uma_probe,
};
module_wmi_driver(uma_driver);

MODULE_AUTHOR("YaguareteOS");
MODULE_DESCRIPTION("Read and set the OneXPlayer firmware UMA frame buffer size");
MODULE_LICENSE("GPL");
