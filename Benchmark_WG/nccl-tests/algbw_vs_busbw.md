# algbw vs busbw

Source: [NCCL tests PERFORMANCE.md](https://github.com/NVIDIA/nccl-tests/blob/master/doc/PERFORMANCE.md)

## Definitions

**algbw** (algorithm bandwidth) = `S / t` — total bytes operated on, divided by wall-clock time. This is what the *user* observes: "I gave NCCL a 1 GB tensor; it returned in 1 ms; throughput was 1 TB/s."

**busbw** (bus bandwidth) = `algbw × correction_factor` — bytes-on-the-wire per GPU per direction. The correction factor accounts for the fact that, inside a collective, each user byte traverses the interconnect more than once.

## Per-collective correction factors

| Op | Factor | Why |
|---|---|---|
| Broadcast / Reduce | 1 | One pass through the tree |
| AllGather / ReduceScatter | (n−1)/n | Each rank moves (n−1)/n of the buffer over the wire |
| AllReduce | 2(n−1)/n | RS + AG = two passes, each (n−1)/n |
| AllToAll | (n−1)/n | Each rank sends (n−1)/n of its buffer to others |

(The doc does not give one for SendRecv; it's effectively 1 since there's no fan-out.)

## Why busbw is the right number to compare to hardware peak

The NCCL doc states the goal directly: busbw "should reflect the speed of the hardware bottleneck: NVLink, PCI, QPI, or network."

The reasoning:

1. **algbw is not rank-independent.** On the same hardware, algbw for AllReduce gets *worse* as you add ranks (factor 2(n−1)/n grows toward 2, so each byte costs more wire time). If you compared algbw to NVLink's 900 GB/s, you'd think the hardware got slower with more GPUs — but the link itself didn't change.

2. **busbw normalizes that out.** It's defined so the number stays roughly constant across rank counts on the same hardware — the only thing it tracks is how saturated the link is.

3. **Hardware specs are stated per direction per link.** NVLink is "900 GB/s per direction." PCIe Gen5 x16 is "63 GB/s per direction." NDR is "50 GB/s per direction." These are bytes-per-second-on-the-wire. So you must convert your measurement into bytes-on-the-wire-per-direction before comparing — and that conversion *is* the busbw correction factor.

## Concrete example: B200 1-node AllReduce (8 GPUs)

- algbw = 481 GB/s (what the application sees)
- busbw = 841 GB/s (= 481 × 2·7/8 = 481 × 1.75)
- NVLink peak = 900 GB/s per direction

Comparing 481 → 900 would say "53% efficient" — wrong, because algbw is artificially deflated by the AllReduce algorithm. Comparing **841 → 900 says 93%** — the correct read of "this AllReduce is pinning NVLink." If you ran the same hardware with 16 ranks, algbw would drop further (factor → 2·15/16 = 1.875) but busbw would stay near 900 — that's exactly the property the metric is designed to expose.

================================================
