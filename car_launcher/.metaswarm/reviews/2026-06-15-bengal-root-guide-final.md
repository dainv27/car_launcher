# Final Review: Bengal Carlink TBox Ambient Root Guide

## Reviewed scope

- The guide distinguishes the known `bengal_515` target from other Qualcomm
  Bengal-branded devices.
- It requires exact stock firmware, checksums, unlock support, and a tested
  restore path before flashing.
- It follows Magisk's image-patching approach and forbids shared patched images.
- It distinguishes temporary `fastboot boot` testing from `init_boot` flashing.
- Qualcomm EDL is documented only as a vendor-specific recovery path.
- It explains that root does not automatically grant Android signature
  permissions required by the launcher.

## Validation

- TBox documentation index links to the new guide.
- Commands are staged as inventory, unlock verification, image patching,
  optional temporary boot, verified flash, validation, and recovery.
- `git diff --check`: clean.

## Residual risk

No public, verified firmware/root procedure for the exact Carlink TBox Ambient
variant was found. The device must not be flashed until its exact stock package
and recovery procedure have been obtained from the vendor.
