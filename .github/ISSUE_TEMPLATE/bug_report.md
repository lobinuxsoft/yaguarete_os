---
name: Bug report
about: Report a defect in YaguareteOS images, the build pipeline, or repository tooling
title: "bug: <short summary>"
labels: bug
assignees: lobinuxsoft
---

<!--
Before filing:
- Confirm you are running an image you actually verified with `cosign verify`.
- Search existing issues to avoid duplicates.
- Do NOT report security vulnerabilities here. See SECURITY.md.
-->

## Summary

<!-- One sentence: what is broken and what should happen instead. -->

## Affected image / commit

- Image tag: `ghcr.io/lobinuxsoft/yaguarete_os:<tag>`
- Image digest: `sha256:<...>` (output of `podman inspect` or `bootc status`)
- Repo commit (if building locally):

## Host environment

- Hardware: CPU / GPU / form factor (desktop, handheld)
- Bootc-capable host used: Bazzite / Bluefin / Aurora / Fedora Atomic / other
- `bootc status` output (if applicable):

```
<paste here>
```

## Reproduction steps

1.
2.
3.

## Expected behavior

<!-- What you expected to happen. -->

## Actual behavior

<!-- What actually happened. Include error messages, exit codes, screenshots. -->

## Logs

<!-- Paste relevant logs or attach a file. Trim aggressively; do not dump
     hundreds of lines. -->

```
<paste here>
```

## Additional context

<!-- Anything else: workarounds you tried, when it started, related issues. -->
