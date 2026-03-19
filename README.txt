9P2000 server in HolyC. It uses the SERIAL0 port for communication.
You can create/modify files and directories in the C:/ drive.

Example with QEMU:
qemu-system-x86_64 -hda TempleOS.qcow2 -m 4G -serial unix:/tmp/templeos,server=on,wait=off

Then, mount /tmp/templeos with a 9P2000 client (for example, 9pfs).

TODO:
*Fix I/O being slow
*Add support for other drives
*Free unused fids so they don't clog up memory
*Add verbose packet/fid logging
*Fix kbd/ms input being blocked
