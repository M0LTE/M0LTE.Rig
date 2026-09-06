# M0LTE.Rig

Two abstractions over an amateur-radio transceiver, both dependency-free and capability-probed: **`IRigControl`**, the station-control (CAT) seam, and **`IRadioControl`**, the channel-sensing seam. Pick `IRigControl` for anything an operator drives (a logger, a digimode app); pick `IRadioControl` for anything that reacts to channel activity (a MAC layer, a CSMA gate). `RigRadioControl` bridges a live `IRigControl` into `IRadioControl` when you have the former and need the latter.

## Station control - `IRigControl`

Get/set **frequency** and **mode**, **PTT**, **SWR / RF-power metering**, and receive-side **DCD / signal-strength** reads, all behind capability probes.

```csharp
IRigControl rig = await RigctldRig.ConnectAsync();   // M0LTE.Rig.Hamlib
// IRigControl rig = await FlrigRig.ConnectAsync();  // M0LTE.Rig.Flrig

await rig.SetFrequencyAsync(14_074_000);
await rig.SetModeAsync(RigMode.PktUsb);

if (rig.Capabilities.HasFlag(RigCapabilities.SwrMeter))
{
    var swr = await rig.ReadSwrAsync();              // dimensionless ratio, 1.0 = perfect
}

if (rig.Capabilities.HasFlag(RigCapabilities.DcdRead))
{
    var busy = await rig.ReadDcdAsync();             // true = carrier present / channel busy
}
```

## Channel sensing - `IRadioControl`

Push carrier-sense (DCD) edges, RSSI, and transmitter keying - what a MAC layer or CSMA gate wants, because a hardware carrier-sense edge leads the modem's decoded frame by a whole preamble.

```csharp
IRigControl rig = await RigctldRig.ConnectAsync();              // any IRigControl backend
IRadioControl radio = new RigRadioControl(rig, ownsRig: true);   // bridge from any IRigControl
// or a native implementation, e.g. M0LTE.Tait.Ccdi's TaitCcdiRadio

radio.CarrierSenseChanged += (_, e) => Console.WriteLine($"channel {(e.Busy ? "busy" : "clear")} at {e.At:O}");

if (radio.Capabilities.HasFlag(RadioCapabilities.RssiRead))
{
    Console.WriteLine($"{await radio.ReadRssiDbmAsync():F1} dBm");
}
```

A driver can also offer **`IRadioSideChannel`** - a small-datagram control plane the radio itself provides (Tait SDM over the radio's internal FFSK modem, for instance), riding the radio's own signalling modem rather than the audio-path modem/TNC. Because it bypasses the audio modem it is mode- and deviation-agnostic, which makes it the natural place to renegotiate the very link it sits beside. Drivers advertise the machinery via `RadioCapabilities.SideChannel`; consumers must still probe that it is enabled in the radio's programming before gating features on it.

## Design

- **`IRigControl`** is the cross-backend common subset for CAT control. Everything a backend might lack is gated by `RigCapabilities` flags discovered at connect time; calling an unadvertised member throws `NotSupportedException`.
- **`IRadioControl`** is the cross-driver common subset for channel sensing, gated the same way by `RadioCapabilities`. The {RSSI-get, busy-get, PTT-set} subset has held across four implementations without an interface change; reserved flags (channel change, frequency, TX power) exist so richer radios can be described before the interface grows those members - that control belongs to `IRigControl` instead.
- **`RigMode`** wraps a canonical token (hamlib vocabulary: `USB`, `LSB`, `CW`, `PKTUSB`, ...) with pass-through for backend-native names (`RigMode.From("DATA-U")`) - mode vocabularies genuinely diverge across backends, so this is not a closed enum.
- **Receive-side reads on `IRigControl`** - `ReadDcdAsync` (true = carrier present / channel busy) and `ReadSignalStrengthDbmAsync` (dBm) - exist so `RigRadioControl` can serve `IRadioControl`'s carrier-sense seam from any CAT rig.
- **`RigRadioControl` is poll-synthesised, not push.** CAT backends have no notification channel, so DCD is sampled by an owned loop and carrier-sense edges are synthesised from consecutive samples; edges shorter than the poll interval are invisible. A failed read fails open (`ChannelBusy = null`, so a CSMA gate never blocks on stale information) and backs off to a slower retry cadence until the rig self-heals. `ownsRig: true` hands the rig's lifetime to the adapter; the default `false` leaves it with the caller, and dispose best-effort unkeys anything the adapter left keyed.
- **Errors** are typed: `RigConnectionException` (link down - retry is sane), `RigTimeoutException`, `RigCommandException` (the backend said no; carries its native code), `RigProtocolException` (unparseable reply).
- **Poll-only backends.** Current `IRigControl` backends (rigctld, flrig) have no push channel; callers own their polling cadence. Native `IRadioControl` drivers (Tait CCDI) push real hardware edges instead.

This package is deliberately **dependency-free** - it does not pull in the rest of the AX.25 stack of any particular project. Implementations:

- [`M0LTE.Rig.Hamlib`](https://www.nuget.org/packages/M0LTE.Rig.Hamlib) - `IRigControl` over hamlib's `rigctld` network protocol (any of hamlib's 200+ rigs, plus the many rigctld-protocol emulators).
- [`M0LTE.Rig.Flrig`](https://www.nuget.org/packages/M0LTE.Rig.Flrig) - `IRigControl` over flrig's XML-RPC server.
- [`M0LTE.Tait.Ccdi`](https://www.nuget.org/packages/M0LTE.Tait.Ccdi) ([repo](https://github.com/M0LTE/M0LTE.Tait.Ccdi)) - a Tait TM8100/TM8200 CCDI driver implementing both seams natively: `TaitCcdiRadio` (`IRadioControl` with push carrier-sense and `IRadioSideChannel`) and `TaitRigControl`, a partial view (PTT + relative RF-power meter) demonstrating a backend that honestly advertises only a slice of the `IRigControl` surface.

AX.25-specific adapters over `IRadioControl` (per-frame RSSI tagging, feeding the AX.25 CSMA gate) live in [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Ax25.Radio`.

Design and research notes live in packet.net, where this library was written: [`docs/research/rig-control-spike.md`](https://github.com/packet-net/packet.net/blob/main/docs/research/rig-control-spike.md).

---
*AGPL-3.0-licensed. Standalone; used by (among others) the [Packet.NET](https://github.com/packet-net/packet.net) stack.*
