## Problem

The installer is heavily driven by `whiptail` dialogs (`yesno`, `menu`, `checklist`, `inputbox`, `msgbox`) across `bash/init.sh`, `bash/main.sh`, and installer helpers in `bash/functions.sh`. That makes headless installation and automated validation difficult in environments where `whiptail` cannot be driven interactively.

The goal is to support **headless installation/testing** without changing how the scripts behave for normal interactive users.

This work should be done on a **new branch named `headless` based on current `master`**, leaving the `wget` fixes isolated on `fixes-649`.

---

## Proposed approach

Add a thin UI abstraction layer around `whiptail` calls so the existing interactive behavior stays the default, but alternate backends can be used when needed:

- an explicit **headless** backend for testing and non-interactive installs
- a plain-text fallback backend for environments where `whiptail` is unavailable or unusable

For the headless path, drive installer choices from a dedicated configuration file that mirrors the available installation options and encodes any mutual-exclusion or coexistence rules.

---

## Implementation plan

Keep this checklist current in this file: mark an item complete when its implementation and applicable validation are complete; add or revise items when the plan changes.

- [x] **Create the `headless` branch**
   - Base it from current `master`
   - Keep all current `wget` prerequisite fixes on `fixes-649`

- [x] **Introduce shared UI wrapper functions**
   - Add wrapper functions in `bash/functions.sh` for prompt types:
     - `ui_yesno`
     - `ui_menu`
     - `ui_checklist`
     - `ui_inputbox`
     - `ui_msgbox`
   - These wrappers should become the only place that knows which UI backend is active

- [x] **Add a headless install mode to `install.sh`**
   - Add a new parameter: `--headless`
   - This mode should explicitly trigger the non-`whiptail` install flow
   - Use the term **headless** consistently

- [x] **Define a dedicated configuration file for headless installs**
   - This file should act like a checklist of available installation options
   - It should document:
     - ADS-B decoder choices
     - UAT decoder choices
     - ACARS decoder choices
     - VDL decoder choices
     - feeder selections
     - portal selection
     - extras selections
     - any required freeform values (device assignments, database settings, tokens, domains, etc.)

- [x] **Document conflicts and coexistence rules in that file**
   - Example conflicts to call out:
     - multiple ADS-B decoders (`dump1090-fa` vs `readsb`)
     - any other truly mutually exclusive selections
   - Also document combinations that are expected to coexist when separate RTL-SDR devices are assigned
     - Based on the current decoder-assignment logic, `dumpvdl2` and `vdlm2dec` should be treated as a **coexistence case to validate**, not assumed to be a forbidden combination
   - Validation should reject invalid combinations with a clear error before install steps begin

- [x] **Add an explicit headless backend**
   - Example trigger: internal mode selected by `--headless`
   - Answers should come primarily from the configuration file
   - Environment variables may still be useful as overrides, but the file should be the documented source of truth

- [x] **Add a plain-text fallback backend**
   - Example trigger:
     - optional explicit override such as `RECEIVER_UI_MODE=text`
     - automatic only when the script is already in `--headless` mode and `whiptail` is unavailable or unusable
   - This backend would:
     - print prompt text to stdout/stderr
     - accept typed responses from stdin
     - emulate yes/no, menu, checklist, inputbox, and msgbox flows closely enough to preserve installer logic
   - Normal interactive installs should still continue to ensure `whiptail` is installed and use it by default
   - In other words: plain-text fallback should **not** silently replace `whiptail` for standard installs just because it is missing; it is for headless/test/text-mode operation

- [x] **Route all dialog calls through the wrapper compatibility layer**
   - Update:
     - `bash/init.sh`
     - `bash/main.sh`
     - `bash/functions.sh`
     - installer scripts that ask follow-up questions
   - Preserve:
     - prompt text
     - defaults
     - branching behavior
     - cancellation semantics where practical

- [ ] **Validate headless behavior**
   - Confirm `install.sh --headless` works without needing `whiptail`
   - Confirm invalid config combinations fail early with useful messages
   - Confirm coexistence cases that should work are supported by config + validation
   - Confirm standard interactive runs still use `whiptail` unchanged
  - Shell-level validation is complete; end-to-end installation still requires a supported Debian/Ubuntu host with the required package and SDR environment.

---

## Best low-risk design

The safest option is:

- wrappers only
- default backend remains `whiptail`
- headless mode must be explicitly enabled with `--headless`
- text mode is used only when selected or when `whiptail` cannot be used in headless operation

That gives testability without changing the normal install experience.

---

## Best overall / most readable design

Yes — the wrapper-plus-headless-config approach is also the clearest long-term design, not just the lowest-risk one.

Why this is the best overall structure:

- prompt handling is centralized instead of duplicated across many scripts
- installer decision logic stays separate from UI transport
- headless installs become declarative and easy to read from a single config file
- coexistence/conflict rules live in one place instead of being implied by scattered prompt flow
- future maintenance is easier because new installer options only need:
  - a config entry
  - a validation rule if needed
  - a wrapper call rather than a raw `whiptail` block

This is more readable than:

- trying to script keystrokes into `whiptail`
- bolting on many one-off `if headless` branches throughout the scripts
- replacing `whiptail` directly in each file without a shared abstraction

So the recommendation is not just “safe”; it is also the most maintainable and readable architecture for supporting both interactive and headless installs.

---

## Notes

- A PTY-backed SSH session can render `whiptail`, but that still does not guarantee a dependable way to step through every dialog programmatically.
- Because the installer uses many different prompt types, solving this cleanly at the wrapper layer is better than trying to special-case individual scripts.
- The headless configuration file should be checked into the repo as a documented example/template, with comments describing valid values and conflicts.
- The plain-text backend should be implemented using the same wrapper interface as headless mode so prompt behavior stays centralized and consistent.
- Confirmed current branch behavior: if `--development` is **not** supplied, `install.sh` defaults `project_branch` to `master`, exports that as `RECEIVER_PROJECT_BRANCH`, and `bash/init.sh` will check out that branch when the current branch differs, then hard-reset it to `origin/${RECEIVER_PROJECT_BRANCH}` when that remote branch exists.