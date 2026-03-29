# SDR Tuning Playbook for ADS-B and UAT

Use this playbook when you want a simple, repeatable way to improve receiver performance.

## One Rule That Prevents Most Mistakes

Change one thing at a time.

If you change gain, antenna position, and filter at once, you will not know what actually helped.

## Before You Start

1. Check system health (CPU, temperature, memory, disk).
2. Choose a normal traffic period.
3. Save a baseline window before making changes.

## Step-by-Step Tuning Loop

### Step 1: Save a Baseline

- Pick a stable 15 to 60 minute window.
- Click Set Baseline.

### Step 2: Make One Small Change

Examples:

- Small gain increase or decrease
- Add or remove filter
- Move or rotate antenna
- Improve cable/connector setup

### Step 3: Compare to Baseline

Turn on compare mode and check:

- Positions per Message
- Aircraft Seen
- Message Rate
- Strong Signal Ratio
- UAT Message Rate and UAT Aircraft

### Step 4: Decide

- Keep the change if quality improves in repeat tests.
- Revert the change if only raw message count rises but quality falls.

## What “Better” Usually Looks Like

- Positions per Message goes up
- Aircraft count is stable or better
- Message activity is stable
- No CPU/temperature stress during the same period

## What “Worse” Usually Looks Like

- Messages go up but useful positions go down
- Strong Signal Ratio jumps without quality gain
- UAT gets worse while ADS-B gets better (or vice versa)
- CPU or temperature spikes after your change

## Suggested Test Window Sizes

- Quick gain check: 5 to 15 minutes
- Filter check: 15 to 30 minutes
- Antenna move check: 30 to 60 minutes
- Stability check: 6 to 24 hours

## Common Situations and What to Try

### Situation: More messages, fewer useful positions

Try:

- Slightly reduce gain
- Improve filtering

### Situation: Strong Signal Ratio suddenly high

Try:

- Reduce gain
- Add attenuation/filtering if available

### Situation: Fewer aircraft during similar traffic times

Try:

- Check antenna direction and placement
- Check connectors and coax path

### Situation: CPU usage climbs with no decoding benefit

Try:

- Reduce host load
- Re-test before making more RF changes

## Keep a Simple Log

For each test, write down:

- Date/time
- One change you made
- Baseline window and test window
- Key KPI changes
- Keep or revert decision

This prevents repeating failed tests and helps you find reliable settings faster.
