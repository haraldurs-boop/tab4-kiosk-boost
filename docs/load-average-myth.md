# The load average on Snapdragon 400 BSP kernels lies to you

## Symptom

You SSH into / ADB into your matissewifi tablet, run `uptime`, and see:

```
load average: 6.03, 6.39, 6.40
```

on a 4-core system. On any normal Linux box this would mean "you are deeply, catastrophically overloaded." You panic. You start killing services.

## Why it's a lie

Run `top -b -n 1 -H | head -3` and look at the summary line:

```
400%cpu  18%user   0%nice  36%sys 346%idle   0%iow   0%irq   0%sirq   0%host
```

**346% idle out of 400% available.** The CPU is barely doing anything. Where is the "load" coming from?

List processes in `D` state (uninterruptible sleep — these count toward load_avg on Linux even when they're not using CPU):

```
$ adb shell "ps -A -o STAT,PID,PCPU,CMD | awk '\$1 ~ /D/ {print}'"
D         6  0.0 kworker/u:0
D<        7  0.0 kworker/u:0H
D       147  0.0 mdss_dsi_event
D       196  0.0 ngd_rx_thread1
D       197  0.0 ngd_notify_sl1
D       429  0.0 mdss_fb0
```

Each one is a kernel thread that lives in `D` more or less permanently on this platform:

- `mdss_fb0`, `mdss_dsi_event` — MDSS display subsystem, waiting on DSI panel events. Always D while the screen is on.
- `ngd_rx_thread1`, `ngd_notify_sl1` — Qualcomm SLIMbus audio IPC. Always D, waiting on SLIMbus messages.
- `kworker/u:*` — async kworkers. Always D while they have work pending.

Six processes, each contributing roughly 1.0 to load_avg (because Linux counts D-state tasks the same as R-state), gives you load ≈ 6, independent of actual CPU use.

## On a mainline kernel

The same tablet booted into postmarketOS with Linux 6.x (`mainline-matissewifi`) reports load around 0.2–0.5 at idle, because mainline drivers don't park themselves in `D` the way the downstream BSP does.

## Practical takeaway

- On this kernel, **`top`'s `idle` column is the truth**. `uptime`'s load average is noise.
- Don't optimize against load. Optimize against user-perceived latency: scroll smoothness, tap-to-response, cold-start times.
- If you ever actually want load to look normal, flash mainline.
