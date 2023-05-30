
## ZFS Setup outside Docker (i.e. the host)
```bash
sudo zfs create SLAB/Backups/Syncoid/ph3.local
sudo zfs allow -u 600 receive,aclinherit,hold,userprop SLAB/Backups/Syncoid/ph3.local
```