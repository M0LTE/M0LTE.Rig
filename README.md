# M0LTE.Rig

One library family for talking to an amateur-radio transceiver, in C#, offering two seams over it.

- **`IRigControl`** is the *station-control* seam: get/set frequency and mode, key PTT, read SWR / RF power / S-meter / DCD, behind a capability probe so you can ask a rig what it can actually do before you ask it to do it. This is what a logger, a digimode app, or anything else with an operator turning the dial wants.
- **`IRadioControl`** is the *channel-sensing* seam: push carrier-sense (DCD) edges, RSSI, and transmitter keying, plus `IRadioSideChannel` for a radio-native small-datagram control plane. This is what a MAC layer or CSMA gate wants - it leads the modem's decoded frame by a whole preamble, which is the head start medium access needs.

Both live in the same `M0LTE.Rig` package, are dependency-free, and share the same capability-flag pattern. `RigRadioControl` bridges the two: wrap any `IRigControl` in it and get `IRadioControl` back, polling the rig's receive-side reads into carrier-sense edges. Pick `IRigControl` if you are building something an operator drives; pick `IRadioControl` if you are building something that reacts to channel activity; use `RigRadioControl` when you have the former and need the latter.

Four packages:

| Package | What it is |
| --- | --- |
| [`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig) | The abstractions: `IRigControl`, `IRadioControl`, `IRadioSideChannel`, `RigRadioControl`, and the exception hierarchy. No dependencies at all. |
| [`M0LTE.Rig.Hamlib`](https://www.nuget.org/packages/M0LTE.Rig.Hamlib) | `IRigControl` over hamlib's `rigctld` network protocol (TCP 4532). Pure managed, no native libhamlib. |
| [`M0LTE.Rig.Flrig`](https://www.nuget.org/packages/M0LTE.Rig.Flrig) | `IRigControl` over flrig's XML-RPC server (TCP 12345). |
| [`M0LTE.Tait.Ccdi`](https://www.nuget.org/packages/M0LTE.Tait.Ccdi) ([repo](https://github.com/M0LTE/M0LTE.Tait.Ccdi)) | Tait TM8100/TM8200 CCDI driver implementing *both* seams natively - `IRadioControl` with push carrier-sense, and a partial `IRigControl` view. |

```sh
dotnet add package M0LTE.Rig.Hamlib
```

```csharp
using M0LTE.Rig;
using M0LTE.Rig.Hamlib;

await using var rig = await RigctldRig.ConnectAsync(new RigctldRigOptions { Host = "localhost" });

await rig.SetFrequencyAsync(14_074_000);
await rig.SetModeAsync(RigMode.PktUsb);

if (rig.Capabilities.HasFlag(RigCapabilities.SwrMeter))
{
    Console.WriteLine($"SWR {await rig.ReadSwrAsync():F1}:1");
}
```

Or take the channel-sensing seam over the same CAT rig, for a CSMA gate:

```csharp
using M0LTE.Rig;
using M0LTE.Rig.Hamlib;

await using var rig = await RigctldRig.ConnectAsync(new RigctldRigOptions { Host = "localhost" });
await using var radio = new RigRadioControl(rig, ownsRig: true);

radio.CarrierSenseChanged += (_, e) => Console.WriteLine($"channel {(e.Busy ? "busy" : "clear")} at {e.At:O}");

if (radio.Capabilities.HasFlag(RadioCapabilities.RssiRead))
{
    Console.WriteLine($"{await radio.ReadRssiDbmAsync():F1} dBm");
}
```

Take `M0LTE.Rig` alone if you are writing something that consumes a rig or a radio (a logger, a digimode app, a bandplan enforcer, a CSMA gate) and want to leave the choice of backend or driver to your user.

## Why the split

These libraries started life inside [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Rig*` and `Packet.Radio*`, where the names implied a connection to packet radio that does not exist: CAT control and channel sensing have nothing to do with AX.25. 0.1.0 shipped them here as two separate families, `M0LTE.Rig` and `M0LTE.Radio`. 0.2.0 folded the radio-control seam into `M0LTE.Rig`, because "Rig" and "Radio" turned out not to carry the distinction between the two seams - `M0LTE.Radio` is retired, and everything it held now lives in this package under the `M0LTE.Rig` namespace.

AX.25-specific adapters over `IRadioControl` (per-frame RSSI tagging, feeding the AX.25 CSMA gate) live separately in [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Ax25.Radio` - this repo stays free of any AX.25 dependency.

## Notes

- **Capabilities are probed, not assumed.** `RigCapabilities` and `RadioCapabilities` are populated at connect time (hamlib via `dump_caps`, flrig by enumerating supported methods, Tait CCDI from the radio's programming). Calling something the rig or radio cannot do throws rather than silently returning a made-up number.
- **No synthesised readings.** flrig's S-meter is an uncalibrated 0-100 needle deflection, so `ReadSignalStrengthDbmAsync` refuses rather than inventing a dBm. hamlib's S-meter is relative to S9, converted using `RigctldRigOptions.S9ReferenceDbm` (default -73 dBm, the IARU Region 1 HF convention; set -93 for VHF/UHF).
- **`RigRadioControl` is poll-synthesised, not push.** CAT backends have no notification channel, so it samples DCD on an owned loop and synthesises carrier-sense edges from consecutive samples; edges shorter than the poll interval are invisible. A failed read fails open (`ChannelBusy = null`, so a CSMA gate never blocks on stale information) and backs off to a slower retry cadence until the rig self-heals. `ownsRig: true` hands the rig's lifetime to the adapter; the default `false` leaves it with the caller, and dispose best-effort unkeys anything the adapter left keyed. `M0LTE.Tait.Ccdi`'s native `IRadioControl` implementation has no such polling penalty - it pushes real hardware DCD edges.
- **Escape hatches exist.** `RigctldRig.TransactRawAsync` / `ReadLevelAsync` and `FlrigRig.CallRawAsync` let you reach anything the abstraction does not model.
- **Time is injectable.** Both `IRigControl` backends and `RigRadioControl` take a `TimeProvider`, so timeout and polling behaviour is testable without real waits.

## Testing

`dotnet test` runs everything against in-process fakes. Six tests in `M0LTE.Rig.Hamlib.Tests` additionally drive a real `rigctld` (hamlib dummy rig, model 1) and report *Skipped* unless it is installed:

```sh
sudo apt install libhamlib-utils
```

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE).
