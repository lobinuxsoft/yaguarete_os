// SPDX-License-Identifier: GPL-2.0-only
/*
 * WMI driver for the OneXPlayer UMA frame buffer interface.
 *
 * The firmware ships an ACPI-WMI class named UMAInterface, described by the
 * device's own BMOF blob. Method 1 (GetUMASize) is a plain read of a 32-bit
 * field in the CPM NV region -- the ASL returns it without triggering an SMI,
 * so nothing is written and nothing is staged. Method 2 (SetUMAsize) does
 * trigger an SMI and is deliberately not wired up yet.
 */

#include <linux/acpi.h>
#include <linux/module.h>
#include <linux/sysfs.h>
#include <linux/wmi.h>

#define UMA_GUID "1F72B0F1-BFEA-4472-9877-6E62937AB616"

/* WmiMethodId values, straight from the UMAInterface schema. */
#define UMA_GET_SIZE 1

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

	/* The schema declares uint32; anything else means we misread the ASL. */
	if (obj->type != ACPI_TYPE_INTEGER)
		ret = -EPROTO;
	else
		*size = (u32)obj->integer.value;

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
static DEVICE_ATTR_RO(uma_size);

static struct attribute *uma_attrs[] = {
	&dev_attr_uma_size.attr,
	NULL
};
ATTRIBUTE_GROUPS(uma);

static int uma_probe(struct wmi_device *wdev, const void *context)
{
	u32 size;
	int ret;

	ret = read_size(wdev, &size);
	if (ret)
		dev_warn(&wdev->dev, "GetUMASize failed: %d\n", ret);
	else
		dev_info(&wdev->dev, "GetUMASize reports %u\n", size);

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
MODULE_DESCRIPTION("Read the OneXPlayer firmware UMA frame buffer size");
MODULE_LICENSE("GPL");
