# Devices Graphs Overview

This guide helps you read the Devices page and make better tuning decisions, even if you are new to SDR.

You do not need deep radio theory to use this documentation. Focus on trends, compare before and after changes, and make one change at a time.

## Start Here (10-Minute Path)

1. Learn the time controls in [time-controls-and-baseline-compare.md](time-controls-and-baseline-compare.md).
2. Learn what each graph means in [graph-reference.md](graph-reference.md).
3. Follow the step-by-step workflow in [sdr-tuning-playbook.md](sdr-tuning-playbook.md).

## What These Docs Help You Do

- Understand if your receiver is getting better or worse.
- Avoid “false wins” where one number improves but overall quality drops.
- Compare your setup before and after a change.
- Separate radio issues from computer/host issues.

## What You Will See on the Devices Page

- Receiver graphs for ADS-B (1090 MHz)
- Receiver graphs for UAT (978 MHz)
- System health graphs (CPU, temperature, memory, disk, network)
- Time-range tools to zoom into events
- Baseline compare mode for before/after checks

## Plain-English Goals

When tuning, aim for these outcomes:

- More useful aircraft positions, not just more raw messages
- Better consistency over time
- Better coverage without instability
- Stable host performance while receiving data

## Quick Vocabulary

- Message: A radio packet received from an aircraft.
- Position: A message with usable location data.
- Baseline: A saved “before” window used for comparison.
- Strong signal ratio: How many received messages are very strong; high is not always better.
- Range: Farthest aircraft distance seen in the selected window.
