# M0LTE.Rig

Rig control (CAT) for amateur-radio transceivers, in C#. Read and set frequency and mode, key PTT, and read SWR / RF power / S-meter / DCD, behind a capability probe so you can ask a rig what it can actually do before you ask it to do it.

Three packages:

| Package | What it is |
| --- | --- |
| [`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig) | The abstraction: `IRigControl`, `RigCapabilities`, `RigMode`, the exception hierarchy. No dependencies at all. |
| [`M0LTE.Rig.Hamlib`](https://www.nuget.org/packages/M0LTE.Rig.Hamlib) | Talks hamlib's `rigctld` network protocol (TCP 4532). Pure managed, no native libhamlib. |
| [`M0LTE.Rig.Flrig`](https://www.nuget.org/packages/M0LTE.Rig.Flrig) | Talks flrig's XML-RPC server (TCP 12345). |

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

Take `M0LTE.Rig` alone if you are writing something that consumes a rig (a logger, a digimode app, a bandplan enforcer) and want to leave the choice of backend to your user.

## Why the split

These libraries started life inside [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Rig*`, where the name implied a connection to packet radio that does not exist: CAT control has nothing to do with AX.25. They moved here so they can be taken on their own merits, and released on their own cadence.

## Notes

- **Capabilities are probed, not assumed.** `RigCapabilities` is populated at connect time (hamlib via `dump_caps`, flrig by enumerating supported methods). Calling something the rig cannot do throws rather than silently returning a made-up number.
- **No synthesised readings.** flrig's S-meter is an uncalibrated 0-100 needle deflection, so `ReadSignalStrengthDbmAsync` refuses rather than inventing a dBm. hamlib's S-meter is relative to S9, converted using `RigctldRigOptions.S9ReferenceDbm` (default -73 dBm, the IARU Region 1 HF convention; set -93 for VHF/UHF).
- **Escape hatches exist.** `RigctldRig.TransactRawAsync` / `ReadLevelAsync` and `FlrigRig.CallRawAsync` let you reach anything the abstraction does not model.
- **Time is injectable.** Both backends take a `TimeProvider`, so timeout behaviour is testable without real waits.

## Testing

`dotnet test` runs everything against in-process fakes. Six tests in `M0LTE.Rig.Hamlib.Tests` additionally drive a real `rigctld` (hamlib dummy rig, model 1) and report *Skipped* unless it is installed:

```sh
sudo apt install libhamlib-utils
```

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE).
