# Changelog

Newest first. Versions are the `v*` tags in this repo; all three packages release together.

## Unreleased

## 0.1.1

- Fixed a dispose-vs-in-flight-command race in both `RigctldRig` and `FlrigRig`: disposing while a command was still in flight used to surface `ObjectDisposedException: SemaphoreSlim` to the caller of that command, and a second command already queued behind it would hang until its own timeout fired. Callers of an in-flight command now get `RigConnectionException` saying the client was disposed, and queued commands are woken immediately with `ObjectDisposedException`.
- Fixed the root `README.md` code sample, which referenced a `RigCapabilities.SwrRead` flag that does not exist; it is `RigCapabilities.SwrMeter`.
- Added an em dash / en dash tripwire to `scripts/check-ascii-output.sh`, so CI fails if any git-tracked file other than `LICENSE` picks one up.
- Reworded doc comments that pointed at packet.net-internal files or plan sections by bare name; they now describe the behaviour directly or link to the file with an absolute URL.

## 0.1.0

First release from this repo.

Split out of [`packet-net/packet.net`](https://github.com/packet-net/packet.net), where these
were `Packet.Rig`, `Packet.Rig.Hamlib` and `Packet.Rig.Flrig`, most recently published as part
of that repo's `lib-v0.33.0`. Git history came across with the code.

- Renamed: packages, namespaces and project directories are all `M0LTE.Rig*` now. The type
  names, the public surface and the behaviour are unchanged, so porting is a `using` edit.
- Dropped a vestigial `InternalsVisibleTo` on `M0LTE.Rig`: the project declares no internal
  types, so the grant did nothing.
- Non-ASCII characters removed from comments and, more importantly, from the one exception
  message that carried one. Printable output is plain ASCII.
