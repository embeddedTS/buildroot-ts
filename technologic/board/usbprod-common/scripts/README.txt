# Runtime Options

A few runtime options exist that are configured simply by creating a file on the root of the USB Image Replicator drive. e.g. `touch /mnt/usb/IR_NO_COMPRESS` The following explains each possible option.

IR_NO_COMPRESS
When capturing, do not compress the data. On slower systems, slower disks, or systems with a large amount of data to capture, the final compression can take a significant amount of time. Creating a file named this will allow a capture, but will not attempt to compress it.

IR_NO_CAPTURE_SD
IR_NO_CAPTURE_SD1
IR_NO_CAPTURE_EMMC
IR_NO_CAPTURE_SATA
When capturing, skip media matching this name. See the respective platform manual for information on which names correspond to which physical media. Note that the names are generic and match what the media is captured as, regardless of actual device node. The names are uniform between capture and write for a given system.

IR_SHELL_ONLY
When booting, skip doing any of the image replication process (capture or write) and instead drop to a login prompt.
