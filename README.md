# Remote Desktop (CBE.next)

Open OnDemand Batch Connect app that runs an Xfce desktop in an Apptainer image with the
`vnc_container` template. Compute nodes only need Apptainer. Draft for
CLIP-HPC/clip-cbe-cluster#162 and #166; meant to live in `CLIP-HPC/bc_osc_desktop` (branch
`cbe`) and be checked out to `/software/ood/<env>/desktop`.

The image is built in [CLIP-HPC/ood-desktop-image](https://github.com/CLIP-HPC/ood-desktop-image)
and pulled as a SIF into `/software/ood/desktop/ood-desktop-<tag>.sif`. The app starts the
desktop with the image's `ood-desktop` launcher and uses its `/usr/bin/websockify`.

## Open points

- `container_image` in `form.yml.erb`: set the tag once the image has a release.
- Slurm in the desktop terminal: the host's Slurm 26.05 client needs glibc 2.38, and the
  Rocky 9 image has 2.34, so `sbatch` and friends are not available in the desktop. This
  needs either an EL10-based image (then bind `/usr/bin/s*`, `/usr/lib64/slurm` and
  `/run/munge`) or a matching Slurm client in the image.
- GPU types in `form.yml.erb` are a fixed list from `sinfo -p g -o %G`; update it when
  GPU nodes change.
