# Remote Desktop (CBE.next)

Open OnDemand Batch Connect app that runs an Xfce desktop in an Apptainer image with the
`vnc_container` template. Compute nodes only need Apptainer. Built for
CLIP-HPC/clip-cbe-cluster#162 and #166; lives in `CLIP-HPC/ood-remote-desktop` (branch
`main`) and is checked out to `/software/ood/<env>/desktop`.

The image is built in [CLIP-HPC/ood-desktop-image](https://github.com/CLIP-HPC/ood-desktop-image)
and pulled as a SIF into `/software/ood/desktop/ood-desktop_<tag>.sif`, with the symlink
`/software/ood/desktop/ood-desktop.sif` pointing at the current release. The app starts the
desktop with the image's `ood-desktop` launcher and uses its `/usr/bin/websockify`.

## Files and Slurm in the desktop

- The network filesystems (`/users`, `/groups`, `/scratch`, `/software`, `/cvmfs`,
  `/programs`, `/appdata`, ...) need no binds: `apptainer.conf` on the compute nodes has
  `mount hostfs = yes`.
- The app binds only what is on the node's local disk: `/run/munge` (munge socket) and
  `/var/spool/slurmd` (the configless `slurm.conf` that `$SLURM_CONF` points to, and the
  `slurmstepd` sockets). It goes through `existing_paths` from the `vnc_container`
  `script_wrapper` in `clusters.d/cbe.yml`, so a path missing on a node is skipped.
- Slurm commands (`sinfo`, `squeue`, `sbatch`, `srun`, `sacct`, ...) come from the image's
  own Slurm client (since ood-desktop-image v1.0.0); no host binaries are bound in.

## Form and submit checks

- **Partitions and GPU types** come from Slurm when the form renders (`cluster_info.rb`):
  only the known partitions `c`, `g` and `m` that the cluster has are offered (orion: `c`
  only), and the GPU types are those on partition `g` (`sinfo -p g -o %G`), with friendly
  labels for known types. The GPU fields are left out on a cluster without `g`, and the
  GPU count is capped at the most GPUs of the chosen type on one node. If `sinfo` fails,
  the 2026-11 atlas lists are used.
- **QOS limits:** every OOD session runs in the `interactive` QOS, whatever the
  partition. `qos_limits.rb` reads its limits (wall time, per-user cores, memory, GPUs
  and sessions) from `sacctmgr` and the user's current sessions from `squeue`, with
  fallback values if either fails. The form shows them as field limits and help text.
- `submit.yml.erb` checks all of this again (a posted value can bypass the form) and stops
  with a clear message instead of a Slurm rejection or a held job. The high memory (`m`)
  partition needs at least 128 GB.
- **Container image (admins only):** the image isn't a form field; `submit.yml.erb` sets
  the default. Members of `perm.cbe.users.admin` get a text field to run another SIF, for
  testing an image. Everyone else gets a hidden field, and `submit.yml.erb` checks the
  group again. The path must be a readable file and is resolved to its real path, so a
  session keeps the image version it started with.

## Open points

- Labels in `cluster_info.rb` for new partitions or GPU types: a new GPU type shows its
  Slurm name until it gets a label; a new partition isn't offered until it is added there.
