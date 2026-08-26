# Contributing

Yes, please. This installer exists because macOS keeps finding new ways to
break a Linux research project, and we cannot own every Mac.

## The most useful thing you can do

**Tell us it worked.** Open an issue saying which Mac, which macOS, and
whether it finished. That sounds trivial; it isn't. Every macOS release
and every hardware generation is a chance for something to break, and we
only find out when somebody says so.

**Tell us it didn't.** Open an issue and attach `~/kimodo-install.log`.
That file has everything: your macOS version, your processor, which step
stopped, and the exact error. With it a fix usually takes an evening.
Without it we are guessing.

Please say which of these you hit, if you can tell:

- it stopped during install → attach the log
- it installed but Kimodo Studio won't open → attach the log
- it generates, but the motion is wrong → describe the prompt and what
  you got instead
- the instructions were confusing → tell us which part, in your words

The last one matters as much as the others. This installer is written for
people who do not use Terminal. If a sentence lost you, that is a bug.

## Code changes

Fork it, change it, open a pull request. Small and focused is easier to
review than large and sweeping.

A few things worth knowing before you start:

- The script must work on **both** Intel and Apple Silicon. Anything
  architecture-specific goes behind a check on `$ARCH`.
- It must be **safe to run twice**. Every step checks whether its work is
  already done. Patches applied to Kimodo's source must be idempotent.
- **Verify, don't assume.** Several patches key off the exact shape of
  upstream's files. When a patch might silently do nothing, check
  afterwards that it landed and say so plainly if it didn't. There are
  examples of this throughout.
- Keep the on-screen wording plain. No jargon the reader has to look up,
  and no promises the installer cannot keep.
- `bash -n install.sh` before you push. `shellcheck` if you have it —
  one warning about `sudo` and redirects is expected and fine.

## Licensing of contributions

This project is not open source. It is free for personal and community
use, but modified copies and commercial use need our written permission
(see [LICENSE](LICENSE)).

That has a consequence for contributions, so we would rather be explicit
than leave it fuzzy:

**By opening a pull request, you agree that your contribution may be
distributed as part of this project under the same terms, and that
KnitMotionTeam may relicense the project in future — including under a
recognised open source licence — without asking you again.**

You keep the copyright in what you wrote. You are not signing it over.
This clause only makes sure the project can keep shipping as one coherent
thing.

If you are not comfortable with that, please open an issue describing the
fix instead of a pull request. A clear description of a bug is genuinely
almost as useful as a patch, and we will credit you either way.

## What we are unlikely to merge

- Changes that only help one machine
- Anything that makes the installer assume Terminal experience
- Bundling NVIDIA's or Meta's code into this repository. The installer
  downloads it from their official sources, and it should stay that way

## Contact

knitmotionteam@gmail.com — for anything that doesn't fit an issue, or if
you would like permission for something the licence asks you to ask about.
