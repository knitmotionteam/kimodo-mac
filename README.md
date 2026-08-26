# Kimodo for macOS

An unofficial installer that sets up NVIDIA's Kimodo motion generation
model to run entirely on your own Mac. No graphics card needed. Nothing
is uploaded. Free.

Made by the **KnitMotion** team.

> This project is not affiliated with, sponsored by, or endorsed by
> NVIDIA, Meta, or Apple. It contains none of their software. It is a
> setup script that downloads their software from their own official
> sources, on your machine, with your consent.

---

## Install

Open Terminal (press ⌘ + Space, type `Terminal`, press Return), then
paste this line and press Return:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/knitmotionteam/kimodo-mac/main/install.sh)"
```

That's it. Nothing is written to disk beforehand, so macOS never marks
anything as quarantined and no security warning appears. The installer
explains each step as it goes and asks before doing anything that needs
your attention.

It is safe to run again: finished steps are skipped, and only what failed
is retried.

Prefer to read it first? You should:

```bash
curl -fsSL https://raw.githubusercontent.com/knitmotionteam/kimodo-mac/main/install.sh | less
```

---

## What you need

| | |
|---|---|
| macOS | 12 (Monterey) or newer |
| Mac | Intel or Apple Silicon — both work |
| Disk | about 40 GB free |
| Memory | 16 GB minimum, 24 GB or more for comfort |
| Account | a free Hugging Face account (the installer walks you through it) |

**About memory, honestly.** Kimodo reads your prompt using an
8-billion-parameter language model. On a Mac there is no graphics card to
put that model on, so it sits in ordinary memory and wants roughly 16 GB
to itself. On a Mac with less, macOS will page it to disk constantly and
generation may be stopped by the system. The installer checks this and
tells you plainly what to expect before it starts.

**About speed.** Generation runs on the processor rather than a graphics
card, so it can take a while. How long depends on your Mac — a faster
machine with more memory finishes considerably sooner. Long and quiet is
normal, not a fault.

**About the install itself.** Most of it is unattended downloading. You
can start it and walk away.

---

## One wait you cannot skip

Kimodo reads prompts using Meta's Llama 3, and Meta requires you to
review and accept their licence before using it. It is free, and approval
usually arrives within a few hours.

The installer asks for this **first**, then sets up everything else while
you wait. If approval hasn't arrived by the time it finishes, run the
installer again later — it skips everything already done and goes
straight to generating your first motion.

---

## After it finishes

Two shortcuts appear on your Desktop:

**Kimodo Studio** — opens the app in your browser at `localhost:7860`.
Everything runs on your Mac; nothing goes over the internet.

**New Motion** — asks for a description, writes an `.npz` file to your
Desktop.

Drag the `.npz` into Blender with KnitMotion and it lands in your Load
Actions list, ready for a Mixamo rig in one click.

---

## If something goes wrong

The installer is safe to run again. It skips what is already done and
retries only what failed, so if it stops halfway, just run it again.

Everything it does is written to `~/kimodo-install.log`. If you get
stuck, send that file to **knitmotionteam@gmail.com** and we will take a
look.

Worth knowing: the log records your Mac's name and your account name,
along with the installation steps. Nothing else.

---

## What this installer does

Kimodo targets Linux machines with NVIDIA graphics cards, which is a
perfectly reasonable thing for a research project to do. Running it on a
Mac means working around a number of differences between the two
platforms. This installer handles:

- Selecting a PyTorch build that works on Intel Macs, and pinning the
  libraries that depend on it
- Setting up Python's certificate store, which is empty on a fresh Mac
- Installing Node.js and CMake without requiring Homebrew
- Adjusting compiler settings so the C++ module builds with Apple's
  Clang, on both Intel and Apple Silicon
- Translating the C++ module's Intel SIMD instructions to ARM on Apple
  Silicon, so the motion polish step builds natively rather than being
  skipped
- Detecting a Terminal running under Rosetta, which would otherwise make
  an Apple Silicon Mac look like an Intel one
- Keeping the whole set of library versions consistent from start to
  finish

Each of these is a separate dead end if you meet it by hand. None of them
are faults in Kimodo; they are the ordinary cost of moving software
between platforms.

---

## Licence

Free for personal and community use. Share it unchanged as much as you
like. Please write to us first if you want to modify it, take pieces of
it into something else, or use it commercially.

This licence covers **only this installer**. The software it downloads
belongs to other people and carries their own terms, which apply to you
directly.

Full terms: [LICENSE](LICENSE)

---

## Credits and trademarks

The motion model is **Kimodo**, by NVIDIA
([nv-tlabs/kimodo](https://github.com/nv-tlabs/kimodo)). The code is
Apache-2.0; the model weights are under the NVIDIA Open Model License.
Prompt understanding uses Meta's Llama 3 under the Meta Llama 3 Community
License.

This repository distributes none of that software. The installer
downloads it from the official sources at install time, and you accept
those licences directly with their owners.

NVIDIA and Kimodo are trademarks of NVIDIA Corporation. Llama and Meta
are trademarks of Meta Platforms, Inc. Apple, Mac and macOS are
trademarks of Apple Inc. Blender is a trademark of the Blender
Foundation. Mixamo is a trademark of Adobe Inc. They are named here only
to identify the software this installer works with. No affiliation or
endorsement is claimed or implied.

Copyright (c) 2026 KnitMotionTeam. All rights reserved.
