# Sanoid Pull Server and Client
This project contains the components to setup a Syncoid "Pull Server" in one
location that will connect to a system that has ZFS datasets that need to be
backed up and pull replicate those datasets to the Pull Server.

I use it specifically to backup data on my home server to a VPS.

## Why Pull
It is usually much easier to have the server with the data connect to a
remote server and "Push" the backup data to that server.  The source just needs
SSH access to the destination.

The downside of the "Push" approach is that it necessarially gives the source
server some permissions on the destination server.  These permissions could
allow someone on a compromised source server to connect to the your backup
repository and delete/corrupt all your backups.

The "Pull" approach limits the impact of either the source or destination being
compromised.
* The destination server can read data on the source server, but not modify it
* The destination server will be receiving an encrypted copy of the source data
  (if the source ZFS dataset is encrypted) and never needs to have the
  encryption keys.  The destination doesn't need to be "trusted" to keep your
  data private.
* The source server cannot modify or delete the backups once they are on the
  destination server.

Quite often the "Pull" direction is difficult to achieve for networking
reasons.  If your source server is behind NAT you need a VPN or port forwards
and firewall rules.  Managing these adds complexity, (if done incorrectly)
possible entrypoints for an attacker, and more oppitunities for backups to
fail.

This "Pull Server" implementation uses the "Chisel" tool to channel the backups
over an outbound (from the source server) HTTPS websocker connection.  The Pull
Server then connects to the source over the established tunnel (over SSH) to
"zfs send" the backups to itself.

## Installation
### SSH Public/Private key pair
```
ssh-keygen -t ed25519 -C "syncoid@<source server name>" -N "" -f ~/.ssh/identities/syncoid@<source server name>
```

### Pull Server (where the backups should be stored)
The pull server will need the following:
* 1x (v)CPU
* 1GiB of RAM
* Enough block storage to hold your backup data
* The ZFS Kernel module
  * If you use Ubuntu 18.04 or newer, you will get this out of the box
    * Unless you're using a VPS provider that uses something other than the
      out-of-the-box Ubuntu Kernel.  If you VPS is a real VM, and not
      something like an OpenVZ container, you should be fine.
* 1x Public IP or ports 80 and 443 forwarded from a public IP
* 1x Public DNS Name that points to the above Public IP
  * If you are a CloudFlare user, you probably DO NOT want to use CloudFlare to
    proxy traffic to this DNS name.  You will potentailly be sending GiB or TiB
    of traffic to this IP and CloudFlare will likely want you to pay for that
    much traffic.
* Docker

I use a reasonably stock Ubuntu 22.04 VM from BuyVM with a 256GiB storage
"Slab".

#### `users.json`
`users.json` allows us to limit the access that the Pull Client has, via
Chisel, on the Pull Server's network.

The following allows the user `<source name>` access only to create a listening
port on the Pull Server, listening on port 10022 on all interfaces.  "all
interfaces" in this context is still just the interfaces/IPs within the Docker
stack.  It is NOT allowing random connections from the internet to connect to
port 10022 and sending them to the Pull Client.
```json
{
  "<source name>:<a password>": [
    "R:0.0.0.0:10022"
  ]
}
```
Each Pull Client will need a unique listening port on the Pull Server.

#### TLS Certificate
All traffic will transit over a TLS encrypted HTTPS tunnel.  The provided
example `docker-compose.yml` will setup certbot to automatically create and 
maintain a LetsEncrypt TLS certificate.



### Pull Client (where the data is)
* The data should already be on ZFS
* If you want the data to be encrypted (private and hidden from the VPS
  provider), the data should be on an encrypted ZFS dataset.
* Docker
* Access to the "syncoid-pull-client" docker image
  * I might upload it to Docker Hub or equiv.
  * Use the file "pull-client/Dockerfile.syncoid-pull-client" to build it
    yourself

```
docker run -v /dev/zfs:/dev/zfs -v /tmp/syncoid-pull-client:/tmp/syncoid-pull-client --privileged -it --entrypoint /usr/bin/bash -e SSH_PUBKEY="<pub key here>" -e CHISEL_AUTH="ph3.local:<password here>" cr.ghanima.net/applications/sanoid/syncoid-pull-client
```

## Backup Scripts - TODO: Rewrite this doco
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


## Doco that needs to be put somewhere better later
### SSH key authentication

**Source Server**
```
zfs allow -u syncoid send,hold,userprop tank/vms
sudo useradd -r -d /var/lib/syncoid -m syncoid
sudo -u syncoid -i
```
```
mkdir .ssh; chmod 700 .ssh
ssh-keygen -t ed25519 -C "ph3@zfs-s3-gateway" -N "" -f ~/.ssh/ph3@zfs-s3-gateway
printf '%b' "Host zfs-s3-gateway\n  HostName        172.31.6.149\n  User            ph3\n  AddKeysToAgent  no\n  identityFile    ~/.ssh/ph3@zfs-s3-gateway\n\n" >>~/.ssh/config
```

```
sudo zfs allow -u ph3 snapshot,create,receive,aclinherit,hold,mount,userprop tank/znapzend
sudo useradd -r -d /var/lib/syncoid -m syncoid
sudo -u syncoid -i
```
```
mkdir .ssh; chmod 700 .ssh
printf '%b' "ssh-ed25519 AAAA...\n" >>~/.ssh/authorized_keys
chmod 600 ~/.ssh/*
```

```
/usr/sbin/syncoid --no-privilege-elevation --debug --dumpsnaps --compress=none --create-bookmark --no-sync-snap --sendoptions="w" "SSD1/VMs/machines/portainer1.ghanima.net" "zfs-s3-gateway:s3bucket/Backups/Syncoid/ph3.local/portainer1.ghanima.net"
```