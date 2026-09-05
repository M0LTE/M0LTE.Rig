# Changelog

Newest first. Versions are the `v*` tags in this repo; all three packages release together.

## Unreleased

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
