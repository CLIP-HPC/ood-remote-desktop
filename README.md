# Remote Desktop (CBE.next)

Open OnDemand Batch Connect app that runs an Xfce desktop in an Apptainer image with the
`vnc_container` template. Compute nodes only need Apptainer. Built for
CLIP-HPC/clip-cbe-cluster#162 and #166; lives in `CLIP-HPC/ood-remote-desktop` (branch
`cbe`) and is checked out to `/software/ood/<env>/desktop`.

The image is built in [CLIP-HPC/ood-desktop-image](https://github.com/CLIP-HPC/ood-desktop-image)
and pulled as a SIF into `/software/ood/desktop/ood-desktop_<tag>.sif`, with the symlink
`/software/ood/desktop/ood-desktop.sif` pointing at the current release. The app starts the
desktop with the image's `ood-desktop` launcher and uses its `/usr/bin/websockify`.

## Form and submit checks

- Every OOD session runs in the `interactive` QOS, whatever the partition. `qos_limits.rb`
  reads its limits (wall time, per-user cores, memory, GPUs and sessions) from `sacctmgr`
  and the user's current sessions from `squeue`, with fallback values if either fails.
  The form shows them as field limits and help text; `submit.yml.erb` checks them again
  and stops with a clear message instead of a Slurm rejection or a held job.
- The high memory (`m`) partition needs at least 128 GB; the GPU fields only apply on `g`.
- **Container image (admins only):** members of `perm.cbe.users.admin` get a text field to
  run another SIF instead of the default, for testing an image. Everyone else gets a hidden
  field, and `submit.yml.erb` checks the group again. The path must be a readable file and
  is resolved to its real path, so a session keeps the image version it started with.

## Open points

- Slurm in the desktop terminal: the host's Slurm 26.05 client needs glibc 2.38, and the
  Rocky 9 image has 2.34, so `sbatch` and friends are not available in the desktop. This
  needs either an EL10-based image (then bind `/usr/bin/s*`, `/usr/lib64/slurm` and
  `/run/munge`) or a matching Slurm client in the image.
- GPU types in `form.yml.erb` are a fixed list from `sinfo -p g -o %G`; update it when
  GPU nodes change.
