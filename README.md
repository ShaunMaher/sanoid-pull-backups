# Sanoid Helper Scripts

But, Sanoid and Syncoid provide all I need.  What are these scripts for?
* Atomic snapshots of all datasets related to a Libvirt VM  
  My home server has a compination of mechanical disks and SSDs that make up
  seperate zpools.  I have VMs that have virtual disks on different zpools.
  These scripts make sure that when one zfs dataset used by a VM is snapshotted,
  all zfs datasets related to the VM are snapshotted at the same time.
  * That's not "Atomic"  
    Before any snapshots are taken the script will:
    * Ask the VM (via the Qemu Guest Agent), to trim it's disks.  Might as well
      back up a nice tidy VM
    * Ask the VM (via the Qemu Guest Agent), to freeze all disk writes
    * Suspend the VM
    Then the snapshots on all related ZFS datasets are taken.

    After the snapshots, and before control is handed back to Sanoid, the VM is
    unpaused and it's filesystems are thawed.
  * The VM is paused and therefore offline!?  For a second or two, yes.
* Syncoid is triggered for each dataset a VM has a disk on.  Each dataset can
  have one or more "destinations" defined as user parameters of the dataset.
  * `systemd-run` is used to execute Syncoid in the background.

## What's incomplete
* These features should be optional and controlled by settings somewhere (more
  userparameters probably)
  * Trim
  * Freeze/Thaw
  * Pause/Unpause.  For VMs that actaully freeze their filesystems, the
    Freeze/Thaw is probably sufficient to ensure consistant backups.
* Cleanup of "atomic" snapshots
* Cleanup of bookmarks created by Syncoid
* Can we make the syncoid part "pull" backups instead of "push" (i.e. syncoid
  runs on a destination machine and reaches out to pull the snapshots from the
  source machine)
  * This is way more secure because the source (which may be compromised) does
    not need access to the destination datasets.  A compromised source can't
    delete it's own backups.