# YaguareteOS

A bootable, image-based Linux distribution built on top of [Bazzite](https://bazzite.gg/) using the [Universal Blue](https://universal-blue.org/) toolchain.

YaguareteOS combines:

- **Gaming-ready base** — inherits Steam, Proton-GE, GameMode, gamescope, MangoHud and the latest AMD/Mesa drivers from Bazzite.
- **Image-based atomic updates** — built on `bootc`. Rebase, rollback, and reproducible builds out of the box.
- **Sovereign supply chain** — built and signed in our own CI; rebase URL points to our own OCI registry (`ghcr.io/lobinuxsoft/yaguarete_os`).
- **Argentine identity** — branding, wallpapers, locale `es-AR` and (eventually) regional packages.

## Status

Early scaffolding. Project pivoted from Archiso to Universal Blue / bootc on 2026-05-06.

## Build locally

Requires `just`, `podman` and a bootc-capable host (Bazzite, Bluefin, Aurora, or Fedora Atomic).

```bash
just build           # build the container image locally
just run-vm-qcow2    # boot the image in a VM via bootc-image-builder
```

See `Justfile` for the full task list.

## Structure

```
Containerfile             FROM bazzite:stable + overlay system_files/ + run build_files/build.sh
build_files/build.sh      package installs and systemd unit enables (runs inside the build)
system_files/             overlay copied verbatim into the image rootfs (wallpapers, configs)
disk_config/              bootc-image-builder TOMLs for ISO / qcow2 / raw outputs
.github/workflows/        CI: build container + build disk images
Justfile                  task runner (build, test, run-vm, clean, etc.)
```

## Rebase from an existing bootc system

```bash
sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:latest
```

## Verifying image signatures

All images published to `ghcr.io/lobinuxsoft/yaguarete_os` are signed with [`cosign`](https://github.com/sigstore/cosign). The public key (`cosign.pub`) lives at the root of this repository.

```bash
# Verify the latest image
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/main/cosign.pub \
  ghcr.io/lobinuxsoft/yaguarete_os:latest
```

A successful verification means the image was built and signed by the official YaguareteOS CI pipeline. If verification fails, do not rebase to that image.

## License

Apache License 2.0 — see `LICENSE`.

---

*Yaguareté: the largest feline of South America, a national symbol of Argentine wildlife.*
