# Design Review: Bengal Carlink TBox Ambient Root Guide

## Decision

Document a recovery-first Magisk image-patching workflow instead of presenting
an unverified model-specific exploit or shared boot image.

## Safety gates

- Identify exact hardware, build fingerprint, slot layout, and boot image type.
- Obtain the exact stock firmware and a tested restore path before flashing.
- Stop if OEM unlock or fastboot flashing unlock is unavailable.
- Never flash an image from another TBox, even if it is also branded Bengal.
- Treat Qualcomm EDL as a vendor recovery path, not a rooting shortcut.

## Project relevance

Root access does not itself grant Android signature permissions such as
`INJECT_EVENTS` or `ADD_TRUSTED_DISPLAY`. The guide explains the remaining ROM,
priv-app allowlist, platform-signing, and SELinux requirements.
