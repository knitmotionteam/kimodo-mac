#!/usr/bin/env bash
#
#  Install Kimodo — macOS
#
#  Made by the KnitMotion team, so that NVIDIA's motion model runs on an
#  ordinary Mac with no setup work from you.
#
#  Copyright (c) 2026 KnitMotionTeam. All rights reserved.
#
#  FREE FOR THE COMMUNITY — worth reading once
#
#    Use it. On as many of your own Macs as you like, for as long as you
#    like, for personal, educational, hobby and creative work. No cost,
#    no account, no permission needed.
#
#    Pass it on. Send it to a friend, post it on a forum, drop it in a
#    Discord. The only conditions: share the file whole and unchanged,
#    leave this notice in it, and don't charge for it.
#
#    Write to us first for anything else. That means changing it and
#    sharing your version, lifting parts of it into a project of your
#    own, or using it commercially — selling it, bundling it with a paid
#    product, or running a paid service on top of it. We're easy to talk
#    to and the answer is usually yes; we just want to know.
#
#    No warranty. This installer downloads and installs software on your
#    Mac and makes changes to it. Run it because you have decided to,
#    not because anyone promised you anything. KnitMotionTeam accepts no
#    liability for what it does to your machine or your work.
#
#    These terms cover this installer only — not Kimodo, and not the
#    model weights. Those are NVIDIA's, under NVIDIA's own licences.
#
#  Questions, problems, permission, or just to say hello:
#  knitmotionteam@gmail.com
#
#  Kimodo itself is NVIDIA's (github.com/nv-tlabs/kimodo, Apache-2.0;
#  model weights under the NVIDIA Open Model License). This installer is
#  an independent piece of work and is not affiliated with, sponsored by
#  or endorsed by NVIDIA.
#
#  HOW TO RUN THIS
#    Open Terminal and paste one line:
#
#      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/knitmotionteam/kimodo-mac/main/install.sh)"
#
#    Nothing is written to disk beforehand, so macOS never marks anything
#    as quarantined and no security warning appears.
#
#    If you saved this file instead of piping it, run it the same way —
#    `bash install.sh` — rather than double-clicking. macOS blocks
#    downloaded scripts that are launched from Finder, and running them
#    through bash sidesteps that entirely.
#
#  Safe to run again: finished steps are skipped. If something fails
#  halfway, run it again — it picks up where it left off.
#
#  Works on Intel and Apple Silicon, macOS 12 and newer. Needs no
#  Homebrew: everything it depends on is fetched a way that works on
#  a completely stock Mac.
#
#  The macOS-specific problems it handles, none of them documented:
#    1. PyTorch 2.2.2 is the last Intel-Mac build -> needs Python 3.11
#    2. transformers 5.x demands torch>=2.4 -> pinned back on Intel
#    3. Python's SSL store is empty on a fresh Mac -> certifi wired in
#    4. The 3D viewer needs Node.js -> installed via nodeenv, not brew
#    5. The C++ extension needs CMake -> installed from PyPI, not brew
#    6. Compiler.h leaves Clang out of the FORCE_INLINE define -> patched
#    7. A Terminal running under Rosetta makes an M-series Mac look like
#       an Intel one -> detected and refused, rather than silently
#       installing a crippled emulated build
#    8. The motion polish module is compiled with -msse4.1 and -mavx,
#       which are Intel-only instructions that Apple Silicon's compiler
#       rejects outright -> those flags are stripped on arm64
#    9. CMake from PyPI installs a Python wrapper that cannot run inside
#       pip's isolated build environment, and the broken wrapper still
#       satisfies "command -v cmake" forever after -> the real binary
#       shipped inside the same package is put on PATH instead
#   11. Later installs can quietly undo the Intel version pins -> pip is
#       given a constraint file so they cannot
#

BRAND="KnitMotion"
OWNER="KnitMotionTeam"
YEAR="2026"
SUPPORT="knitmotionteam@gmail.com"
VERSION="2.2"
COPYRIGHT="Copyright (c) $YEAR $OWNER. All rights reserved."
LICENSE_LINE="Free for personal and community use. Ask us before changing or selling."

VENV="$HOME/kimodo-env"
SRC="$VENV/src"
NODEENV="$VENV/nodeenv"
CONSTRAINTS="$VENV/pip-constraints.txt"
PY_VER="3.11.9"
PY_URL="https://www.python.org/ftp/python/${PY_VER}/python-${PY_VER}-macos11.pkg"
LOG="$HOME/kimodo-install.log"
GATED="meta-llama/Meta-Llama-3-8B-Instruct"
TOKEN_URL="https://huggingface.co/settings/tokens/new?tokenType=read"
DESKTOP="$HOME/Desktop"

DISK_NEEDED=40      # GB. Model weights, checkpoints, Node, build artefacts.
RAM_COMFORTABLE=24  # GB. Below this, generation is slow.
RAM_TIGHT=16        # GB. Below this, generation may be killed outright.

# Piped through `bash -c`, there is no script file, so there is also no
# window of our own to hold open at the end.
case "$0" in
    bash|-bash|sh|-sh|/bin/bash|/bin/sh) RUNMODE="pipe" ;;
    *)                                   RUNMODE="file" ;;
esac

cd "$HOME" || exit 1
mkdir -p "$DESKTOP" 2>/dev/null

# Keep the previous log rather than destroying the evidence of the run
# that failed. Each run gets its own dated banner.
{
    printf '\n\n================================================================\n'
    printf 'Kimodo install run: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s installer version %s\n' "$BRAND" "$VERSION"
    printf '%s\n' "$COPYRIGHT"
    printf '================================================================\n'
} >> "$LOG" 2>/dev/null

export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1

# Kimodo was written for NVIDIA cards. If any part of it reaches for
# Apple's GPU on an M-series Mac, it will hit operations Metal has no
# implementation for, and PyTorch raises instead of coping. This tells
# PyTorch to quietly run those on the processor rather than stop. It has
# no effect on Intel Macs and no effect if the GPU is never used.
export PYTORCH_ENABLE_MPS_FALLBACK=1

# --- presentation ------------------------------------------------------------

if [ -t 1 ]; then
    B=$'\033[1m'; DIM=$'\033[2m'; R=$'\033[0m'
    GRN=$'\033[0;32m'; YEL=$'\033[0;33m'; RED=$'\033[0;31m'; CYN=$'\033[1;36m'
else
    B=''; DIM=''; R=''; GRN=''; YEL=''; RED=''; CYN=''
fi

STEPS=12
N=0
AWAITING=no
POSTPROC=yes    # set to "no" if the C++ motion-polish module cannot be built

line()   { printf '%s\n' "$DIM----------------------------------------------------------------$R"; }
step()   {
    N=$((N + 1))
    printf '\n%s[%d/%d] %s%s' "$CYN$B" "$N" "$STEPS" "$1" "$R"
    printf '%*s%s%s%s\n' $(( 52 - ${#1} )) '' "$DIM" "$BRAND" "$R"
    line
}
head2()  { printf '\n%s%s%s\n' "$CYN$B" "$1" "$R"; line; }
ok()     { printf '  %s+%s %s\n' "$GRN" "$R" "$1"; }
info()   { printf '  %s-%s %s\n' "$DIM" "$R" "$1"; }
warn()   { printf '  %s!%s %s\n' "$YEL" "$R" "$1"; }
fail()   { printf '\n  %sx %s%s\n' "$RED" "$1" "$R"; }

# Every prompt reads from the terminal directly, so piped stdin can never
# swallow an answer and leave the installer looking frozen.
have_tty() { [ -r /dev/tty ]; }

pause() {
    if have_tty; then
        printf '\n  %sPress return to continue.%s\n' "$DIM" "$R"
        read -r _ < /dev/tty
    fi
}

finish() {
    if [ "$RUNMODE" = file ]; then
        printf '\n  %sPress return to close.%s\n' "$DIM" "$R"
        have_tty && read -r _ < /dev/tty
    else
        printf '\n'
    fi
    exit "${1:-0}"
}

log_tail() {
    printf '\n  %sLast lines of the log:%s\n' "$DIM" "$R"
    tail -n 15 "$LOG" 2>/dev/null | sed 's/^/    /'
}

die() {
    fail "$1"
    if [ -n "${2:-}" ]; then
        printf '\n  What to try:\n'
        printf '%s\n' "$2" | sed 's/^/    /'
    fi
    log_tail
    printf '\n  %sFull log: %s%s\n' "$DIM" "$LOG" "$R"
    finish 1
}

trap 'printf "\n\n  %sInterrupted. Nothing is broken — open this installer\n  again and it continues where it stopped.%s\n\n" "$YEL" "$R"; exit 130' INT

# Quiet, three attempts, reports the outcome either way.
try() {
    desc="$1"; shift
    printf '  %s-%s %s...\n' "$DIM" "$R" "$desc"
    attempt=1
    while [ "$attempt" -le 3 ]; do
        if "$@" >>"$LOG" 2>&1; then
            ok "$desc"
            return 0
        fi
        attempt=$((attempt + 1))
        [ "$attempt" -le 3 ] && sleep 3
    done
    warn "$desc — didn't work, trying another way"
    return 1
}

# Yes/no question. Return is the safe default given in $2 (yes|no).
confirm() {
    _q="$1"; _default="$2"; _ans=""
    have_tty || { [ "$_default" = yes ]; return; }
    if [ "$_default" = yes ]; then
        printf '  %s [%sY%s/n]: ' "$_q" "$B" "$R"
    else
        printf '  %s [y/%sN%s]: ' "$_q" "$B" "$R"
    fi
    read -r _ans < /dev/tty
    case "$_ans" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo])     return 1 ;;
        '')                [ "$_default" = yes ] ;;
        *)                 [ "$_default" = yes ] ;;
    esac
}

# --- network and hugging face helpers ----------------------------------------

net_ok() {
    curl -fsS -m 20 -I -o /dev/null https://huggingface.co/ 2>>"$LOG"
}

hf_name() {
    python -c 'from huggingface_hub import whoami; print(whoami().get("name",""))' 2>/dev/null
}

# The token goes in through the environment, never through the command
# line, so it cannot be read out of `ps` by anything else on the machine.
hf_login() {
    KIMODO_HF_TOKEN="$1" python -c 'import os
from huggingface_hub import login
login(token=os.environ["KIMODO_HF_TOKEN"], add_to_git_credential=False)' >>"$LOG" 2>&1 && return 0
    # Fallback for older huggingface_hub releases that predate login()'s
    # current signature.
    KIMODO_HF_TOKEN="$1" python -c 'import os
from huggingface_hub import login
login(token=os.environ["KIMODO_HF_TOKEN"])' >>"$LOG" 2>&1
}

can_reach_gated() {
    KIMODO_GATED="$GATED" python -c 'import os, sys
from huggingface_hub import snapshot_download
try:
    snapshot_download(os.environ["KIMODO_GATED"], allow_patterns=["config.json"])
except Exception as e:
    print(type(e).__name__, e)
    sys.exit(1)' >>"$LOG" 2>&1
}

# --- welcome -----------------------------------------------------------------

clear
cat <<'ART'

   _  ___                 _
  | |/ (_)_ __ ___   ___ | |_/\  /\___
  | ' /| | '_ ` _ \ / _ \| __/ /_/ / _ \
  | . \| | | | | | | (_) | |_\__  | (_) |
  |_|\_\_|_| |_| |_|\___/ \__|  |_|\___/

  Local install for macOS

ART
printf '  %sby KnitMotion%s        %sinstaller v%s%s\n' "$B" "$R" "$DIM" "$VERSION" "$R"
printf '  %s%s%s\n\n' "$DIM" "$COPYRIGHT" "$R"
cat <<EOF
  This sets up NVIDIA Kimodo so it generates character animation
  entirely on your own Mac. No graphics card needed. Nothing is
  uploaded. Free.

  Kimodo is NVIDIA's research model, built for their graphics cards.
  Getting it to run on a Mac takes a dozen undocumented workarounds.
  ${B}${BRAND}${R} worked those out and packed them into this installer, so
  you only have to press return a few times.

  ${DIM}Free for you, and free to pass on unchanged. If you want to modify
  it or use it commercially, just write to us first — ${SUPPORT}.
  Full terms are in the comments at the top of this file.${R}

  ${B}Three things worth knowing before you start:${R}

  1. You need a free Hugging Face account. We'll do that first.

  2. Meta has to approve your use of the language model Kimodo
     reads prompts with. Approval usually lands within a few
     hours. This installer asks for it up front, then installs
     everything else while you wait.

  3. Kimodo was built for NVIDIA graphics cards. On a Mac it runs
     on the processor instead, which works but is slow, and it
     leans hard on memory. This installer will tell you honestly
     what to expect on your particular Mac in a moment.

  Disk space needed: about ${DISK_NEEDED} GB. Time: roughly an hour or two,
  most of it unattended downloading. You can leave it running.
EOF
pause

# --- 1. system ---------------------------------------------------------------

step "Checking your Mac"

[ "$(uname -s)" = "Darwin" ] || die "This installer is for macOS."

# A Terminal launched with "Open using Rosetta" makes an Apple Silicon Mac
# report itself as Intel. Installing on that basis produces an emulated,
# needlessly hobbled setup, so refuse rather than guess.
TRANSLATED="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
if [ "$TRANSLATED" = "1" ]; then
    fail "This Terminal is running under Rosetta."
    cat <<EOF

  This is an Apple Silicon Mac, but Rosetta is making it look like an
  Intel one. Installing now would build a slow emulated copy of Kimodo.

  ${B}To fix it:${R}

    1  Quit Terminal completely (Terminal menu > Quit Terminal)
    2  Open Finder > Applications > Utilities
    3  Right-click Terminal, choose Get Info
    4  Untick "Open using Rosetta"
    5  Close the window and open this installer again

EOF
    log_tail
    finish 1
fi

MACOS="$(sw_vers -productVersion)"
MAJOR="$(printf '%s' "$MACOS" | cut -d. -f1)"
ARCH="$(uname -m)"
RAM=$(( $(sysctl -n hw.memsize) / 1073741824 ))

# -P forces single-line POSIX output, so a long device name can never wrap
# and turn the "available" column into something non-numeric.
FREE="$(df -Pg "$HOME" 2>/dev/null | awk 'END {print $4}')"
case "$FREE" in
    ''|*[!0-9]*) FREE="" ;;
esac

if [ -n "$FREE" ]; then
    ok "macOS ${MACOS}, ${ARCH}, ${RAM} GB memory, ${FREE} GB free"
else
    ok "macOS ${MACOS}, ${ARCH}, ${RAM} GB memory"
    warn "Could not read free disk space. Make sure you have ${DISK_NEEDED} GB spare."
fi

if [ "$MAJOR" -lt 12 ] 2>/dev/null; then
    die "macOS 12 (Monterey) or newer is needed. This Mac runs ${MACOS}."
fi

if [ -n "$FREE" ] && [ "$FREE" -lt "$DISK_NEEDED" ]; then
    die "Only ${FREE} GB free, and about ${DISK_NEEDED} GB is needed." \
"The language model alone is around 16 GB, and the Kimodo checkpoints,
Node.js and the build files account for the rest. Free up some space
and run this again."
fi

if [ "$ARCH" = "x86_64" ]; then
    TORCH="torch==2.2.2"; PIN=yes
    info "Intel Mac: PyTorch will be pinned to the last supported build"
else
    TORCH="torch"; PIN=no
    info "Apple Silicon: current PyTorch will be used"
fi

# Honest expectations. The text encoder is an 8-billion-parameter model.
# On a Mac there is no GPU to put it on, so it lives in ordinary memory.
if [ "$RAM" -lt "$RAM_TIGHT" ]; then
    printf '\n'
    warn "${RAM} GB of memory is below what this really needs."
    warn ""
    warn "Kimodo reads your prompt with an 8-billion-parameter language"
    warn "model. On a Mac that model sits in ordinary memory, and it wants"
    warn "roughly 16 GB to itself. On this Mac macOS will have to page it"
    warn "to disk constantly, so generation will either take a very long"
    warn "time or be stopped by the system with a 'Killed: 9' message."
    warn ""
    warn "Everything will still install correctly. Whether it generates is"
    warn "genuinely uncertain, and that is not something this installer can"
    warn "fix. Closing every other app first gives it the best chance."
    printf '\n'
    if ! confirm "Install anyway?" no; then
        printf '\n  %sNothing has been changed. Come back with a Mac that has\n  %d GB of memory or more.%s\n' \
            "$DIM" "$RAM_TIGHT" "$R"
        finish 0
    fi
elif [ "$RAM" -lt "$RAM_COMFORTABLE" ]; then
    info "${RAM} GB of memory is enough, but a short clip can still take"
    info "a while. Close other apps before generating."
else
    info "${RAM} GB of memory is comfortable for this."
fi

if [ "$ARCH" = "x86_64" ]; then
    info "On Intel processors generation is slower still. Allow plenty of"
    info "time for your first clip and do not worry when it goes quiet."
fi

# Homebrew is optional here, but if it exists and isn't on PATH, use it.
for d in /opt/homebrew/bin /usr/local/bin; do
    if [ -x "$d/brew" ]; then
        case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    fi
done
export PATH

# xcode-select -p happily succeeds while pointing at a deleted Xcode.app,
# and it says nothing about the licence having been accepted. Test the two
# tools we actually use instead. The xcode-select check comes first and
# short-circuits, so we never trigger the install dialog by accident.
tools_ok() {
    xcode-select -p >/dev/null 2>&1 \
        && git --version >/dev/null 2>&1 \
        && clang --version >/dev/null 2>&1
}

if ! tools_ok; then
    if ! xcode-select -p >/dev/null 2>&1; then
        warn "Apple's developer tools are missing. A dialog will appear now."
        warn "Click Install, wait for it to finish, then come back here."
        xcode-select --install >/dev/null 2>&1
        pause
    fi

    # The download can still be running when the user comes back.
    waited=0
    while ! tools_ok && [ "$waited" -lt 3 ]; do
        if xcode-select -p >/dev/null 2>&1 && ! git --version >/dev/null 2>&1; then
            break   # installed but broken — a licence problem, not a wait
        fi
        warn "Still installing. Waiting another minute."
        sleep 60
        waited=$((waited + 1))
    done

    if ! tools_ok; then
        die "Apple's developer tools are not usable yet." \
"If the install dialog is still running, let it finish and open this
installer again.

If it has finished, the licence probably has not been accepted. Run this
in Terminal, agree to the licence, then start over:
  sudo xcodebuild -license accept

If that reports no Xcode, run this instead and start over:
  xcode-select --install"
    fi
fi
ok "Developer tools present and working"

# --- 2. python ---------------------------------------------------------------

step "Finding Python 3.11"

# A Python built for the wrong architecture would create a venv for the
# wrong architecture, and every wheel from then on would be the wrong one.
py_arch_ok() {
    _m="$("$1" -c 'import platform; print(platform.machine())' 2>/dev/null)"
    [ "$_m" = "$ARCH" ]
}

PY=""
for c in "$(command -v python3.11 2>/dev/null)" \
         "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11" \
         "/opt/homebrew/bin/python3.11" "/usr/local/bin/python3.11"; do
    [ -n "$c" ] && [ -x "$c" ] || continue
    "$c" -c 'import sys' >/dev/null 2>&1 || continue
    if py_arch_ok "$c"; then
        PY="$c"; break
    else
        info "Ignoring $c — it is built for the wrong architecture"
    fi
done

if [ -z "$PY" ]; then
    info "Not installed. Downloading the official package (about 45 MB)."

    net_ok || die "No connection to the internet." \
"Check your Wi-Fi or cable and run this installer again."

    TMPDIR_PY="$(mktemp -d)"
    TMP="$TMPDIR_PY/python.pkg"
    curl -fL --progress-bar "$PY_URL" -o "$TMP" \
        || die "Download failed." "Check your connection, or install Python ${PY_VER}
by hand from python.org and run this again."

    # Ask for the password with a visible prompt of our own, before the
    # installer runs with its output going to the log. Otherwise the
    # window can sit there looking frozen while sudo waits unseen.
    printf '\n'
    warn "macOS needs your login password to install Python."
    warn "This is Apple's own installer. Nothing is sent anywhere."
    printf '\n'
    if have_tty; then
        sudo -v < /dev/tty || die "Administrator permission was not given." \
"Python has to be installed system-wide. Use an account that can
administer this Mac, or install Python ${PY_VER} by hand from python.org
and run this installer again."
    fi

    sudo installer -pkg "$TMP" -target / >>"$LOG" 2>&1 \
        || die "The Python installer failed." "Try opening the package by hand: $TMP"

    PY="/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11"
    [ -x "$PY" ] || die "Python 3.11 is still not there after installing."
    py_arch_ok "$PY" || die "The Python that installed is for the wrong architecture."
    rm -rf "$TMPDIR_PY" 2>/dev/null
fi
ok "$("$PY" --version 2>&1) at $PY"

CERTS="/Applications/Python 3.11/Install Certificates.command"
if [ -f "$CERTS" ]; then
    try "Running Apple's certificate helper" bash "$CERTS" || true
fi

# --- 3. environment ----------------------------------------------------------

step "Creating an isolated environment"
info "Everything goes in ${VENV}. Nothing touches your system Python."

# Reusing an environment left behind by an older attempt is only safe if it
# is the right Python and the right architecture. Otherwise the mismatch
# surfaces much later, as something unrelated and impossible to read.
venv_usable() {
    [ -x "$VENV/bin/python" ] || return 1
    KIMODO_WANT_ARCH="$ARCH" "$VENV/bin/python" -c 'import os, sys, platform
sys.exit(0 if sys.version_info[:2] == (3, 11)
         and platform.machine() == os.environ["KIMODO_WANT_ARCH"] else 1)' 2>/dev/null
}

if [ -d "$VENV" ] && venv_usable; then
    ok "Already there, reusing it"
else
    if [ -d "$VENV" ]; then
        warn "The environment there is unusable or built for the wrong"
        warn "Python. Replacing it. Downloaded models are kept."
        rm -rf "$VENV"
    fi
    "$PY" -m venv "$VENV" >>"$LOG" 2>&1 || die "Could not create the environment."
    venv_usable || die "The environment was created but is not usable."
    ok "Created"
fi

# shellcheck disable=SC1091
. "$VENV/bin/activate" || die "Could not activate the environment."

try "Updating installer tools" python -m pip install --upgrade pip setuptools wheel \
    || die "pip could not update itself." "Usually a network problem. Try again in a moment."

try "Installing certificates" python -m pip install --upgrade certifi \
    || die "Could not install certificates."

# Wire the bundle into everything downstream: pip, requests, and the Node
# download the 3D viewer performs. A stock Mac has none of this set up.
CA="$(python -m certifi 2>/dev/null)"
if [ -n "$CA" ] && [ -f "$CA" ]; then
    export SSL_CERT_FILE="$CA"
    export REQUESTS_CA_BUNDLE="$CA"
    export NODE_EXTRA_CA_CERTS="$CA"
    ok "Secure downloads configured"
else
    die "Certificate bundle not found." "Later downloads would fail silently. Run this again."
fi

try "Adding Hugging Face tools" python -m pip install --upgrade huggingface_hub \
    || die "Could not install the Hugging Face tools."

# --- 4. hugging face ---------------------------------------------------------

step "Hugging Face account and model access"

if ! net_ok; then
    die "No connection to Hugging Face." \
"Check your internet connection and run this installer again. If you are
on a work or school network, it may be blocking huggingface.co."
fi

USER_NAME="$(hf_name)"
if [ -z "$USER_NAME" ]; then
    cat <<'GUIDE'

  +------------------------------------------------------------+
  |  This part needs you. About five minutes.                  |
  |                                                            |
  |  A browser window is opening on the Hugging Face token     |
  |  page. If you don't have an account yet, it will offer     |
  |  to make one. It's free.                                   |
  |                                                            |
  |  On that page:                                             |
  |                                                            |
  |    1  Give the token any name you like                     |
  |    2  Click Create token                                   |
  |    3  Click the copy button next to the long string        |
  |                                                            |
  |  Then come back here and paste it.                         |
  |                                                            |
  |  The token starts with  hf_  and is about 40 characters.   |
  +------------------------------------------------------------+

GUIDE
    info "Opening the token page in your browser"
    open "$TOKEN_URL" 2>/dev/null
    sleep 2

    ATTEMPT=0
    while true; do
        ATTEMPT=$((ATTEMPT + 1))
        if [ "$ATTEMPT" -gt 6 ]; then
            die "Couldn't get a working token." \
"Nothing is broken and nothing is lost. Create a Read token at
  $TOKEN_URL
then run this installer again."
        fi

        printf '\n  %sPaste your token, then press return.%s\n' "$B" "$R"
        printf '  %sNothing will appear on screen as you paste. That is normal.%s\n' "$DIM" "$R"
        printf '\n  Token: '

        TOKEN=""
        IFS= read -r -s TOKEN < /dev/tty
        printf '\n'
        TOKEN=$(printf '%s' "$TOKEN" | tr -d '[:space:]')

        if [ -z "$TOKEN" ]; then
            warn "Nothing was pasted."
            warn "Use Cmd-V to paste. You cannot skip this step by pressing return."
            continue
        fi

        case "$TOKEN" in
            hf_*) ;;
            *)
                warn "That doesn't look like a Hugging Face token."
                warn "Tokens begin with  hf_  and contain no spaces."
                warn "Check you copied the token itself, not the page address."
                continue
                ;;
        esac

        printf '  %s-%s Checking that token with Hugging Face...\n' "$DIM" "$R"
        if hf_login "$TOKEN"; then
            USER_NAME="$(hf_name)"
            if [ -n "$USER_NAME" ]; then
                TOKEN=""
                break
            fi
        fi

        TOKEN=""
        warn "Hugging Face did not accept that token."
        warn "It may have been copied incompletely, or it may have expired."
        warn "Create a fresh one and try again."
        open "$TOKEN_URL" 2>/dev/null
    done
fi
ok "Signed in as ${USER_NAME}"

if can_reach_gated; then
    ok "Meta has approved your access"
else
    cat <<'GUIDE'

  +------------------------------------------------------------+
  |  One gate left, and this one has a queue.                  |
  |                                                            |
  |  Meta requires you to accept the Llama 3 licence before    |
  |  using the model. It's free. Review usually clears within  |
  |  a few hours.                                              |
  |                                                            |
  |  On the page opening now:                                  |
  |                                                            |
  |    1  Find the licence box near the top                    |
  |    2  Click "Expand to review and access"                  |
  |    3  Fill the form. For Affiliation, anything works,      |
  |       including "Independent"                              |
  |    4  Tick the box and click Submit                        |
  |                                                            |
  |  Then come straight back here. This installer keeps going  |
  |  and sets up everything else while you wait.               |
  +------------------------------------------------------------+

GUIDE
    info "Opening the licence page in your browser"
    open "https://huggingface.co/${GATED}" 2>/dev/null
    sleep 2
    pause
    if can_reach_gated; then
        ok "Approved already. That was fast."
    else
        AWAITING=yes
        warn "Not approved yet. That's expected."
        warn "Carrying on with the rest of the install."
    fi
fi

# --- 5. pytorch --------------------------------------------------------------

step "Installing PyTorch"

# On Intel there is no PyTorch newer than 2.2.2, and no NumPy 2. Later
# installs would happily replace both. A constraint file stops them:
# pip applies it to every install from here on, so the pins survive
# Kimodo, the viewer, and anything they drag in.
if [ "$PIN" = yes ]; then
    printf 'torch==2.2.2\nnumpy<2\n' > "$CONSTRAINTS"
    export PIP_CONSTRAINT="$CONSTRAINTS"
    info "Version pins locked in so later installs cannot undo them"
fi

if python -c "import torch" >/dev/null 2>&1; then
    ok "Already installed ($(python -c 'import torch;print(torch.__version__)' 2>/dev/null))"
else
    info "About 200 MB."
    try "Downloading PyTorch" python -m pip install "$TORCH" \
        || die "PyTorch would not install." \
"If the log says 'no matching distribution', there's no build of that
version for this Mac. Send the log to ${BRAND}: ${SUPPORT}"
    ok "PyTorch $(python -c 'import torch;print(torch.__version__)' 2>/dev/null)"
fi

if [ "$PIN" = yes ]; then
    if python -c "import numpy, sys; sys.exit(0 if numpy.__version__ < '2' else 1)" 2>/dev/null; then
        ok "NumPy already matched to this PyTorch build"
    else
        try "Matching NumPy to this PyTorch build" python -m pip install "numpy<2" \
            || die "Could not adjust NumPy."
    fi
fi

# --- 6. node -----------------------------------------------------------------

step "Installing Node.js"
info "The 3D viewer builds its web interface with this."

# Anything already on PATH from a previous run of this installer
[ -x "$NODEENV/bin/node" ] && PATH="$NODEENV/bin:$PATH" && export PATH

if command -v node >/dev/null 2>&1; then
    ok "Already available ($(node --version 2>/dev/null))"
else
    # nodeenv fetches an official prebuilt Node straight from nodejs.org.
    # No Homebrew, no admin password, and it lands inside our own folder.
    try "Adding the Node installer" python -m pip install --upgrade nodeenv \
        || die "Could not install nodeenv."

    if try "Downloading Node.js (about 50 MB)" nodeenv --node=lts --prebuilt "$NODEENV"; then
        PATH="$NODEENV/bin:$PATH"; export PATH
        hash -r 2>/dev/null || true
    fi

    if ! command -v node >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
        try "Trying Homebrew instead" brew install node
        hash -r 2>/dev/null || true
    fi

    command -v node >/dev/null 2>&1 \
        || die "Node.js would not install, and the 3D viewer needs it." \
"Install Node from nodejs.org (the LTS button), then run this installer
again. Everything you've done so far is kept."
    ok "Node.js $(node --version 2>/dev/null)"
fi

# --- 7. build tools ----------------------------------------------------------

step "Installing build tools"
info "Kimodo has a small C++ part that has to be compiled here."
info "It ensures character feet do not slide on the ground."

# Being on PATH is not the same as working. The cmake package from PyPI
# installs a Python wrapper script into the environment, and that wrapper
# cannot run inside the isolated environment pip builds packages in: it
# dies with "No module named 'cmake'" and takes the whole build with it.
# The wrapper still answers `command -v cmake`, so every later run
# believes CMake is fine and quietly repeats the same failure.
cmake_works() { cmake --version >/dev/null 2>&1; }

# The same package also ships the genuine CMake executable. Putting that
# directory ahead of the wrapper hands every build a plain binary with no
# Python involved, which works under build isolation.
use_real_cmake() {
    _d="$(python -c 'import cmake, os
print(os.path.join(os.path.dirname(cmake.__file__), "data", "bin"))' 2>/dev/null)"
    [ -n "$_d" ] && [ -x "$_d/cmake" ] || return 1
    PATH="$_d:$PATH"; export PATH
    hash -r 2>/dev/null || true
    return 0
}

# Deal with a wrapper left by an earlier run before anything else, or it
# will keep hiding every working CMake on this Mac.
if [ -f "$VENV/bin/cmake" ] && head -n 5 "$VENV/bin/cmake" | grep -q "from cmake import"; then
    if use_real_cmake && cmake_works; then
        ok "Switched to the real CMake binary inside the Python package"
    else
        warn "Removing a CMake wrapper that cannot run inside pip builds"
        rm -f "$VENV/bin/cmake" "$VENV/bin/ctest" "$VENV/bin/cpack"
        hash -r 2>/dev/null || true
    fi
fi

if ! cmake_works; then
    try "Installing CMake" python -m pip install --upgrade cmake
    use_real_cmake
fi

# Homebrew is the fallback, not the first move: it needs an administrator
# password and a large download, and the step above usually succeeds.
if ! cmake_works; then
    warn "CMake still not working. Falling back to Homebrew."
    if ! command -v brew >/dev/null 2>&1; then
        printf '\n'
        warn "Installing Homebrew, the standard package manager for macOS."
        warn "macOS will ask for your login password."
        warn "As you type it, nothing shows on screen. That is normal."
        printf '\n'

        if have_tty; then
            sudo -v < /dev/tty || die "Administrator permission was not given. Homebrew needs this."
        fi

        info "Running the official Homebrew installer..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null

        [ -x "/opt/homebrew/bin/brew" ] && PATH="/opt/homebrew/bin:$PATH"
        [ -x "/usr/local/bin/brew" ] && PATH="/usr/local/bin:$PATH"
        export PATH
        hash -r 2>/dev/null || true
    fi

    if command -v brew >/dev/null 2>&1; then
        try "Installing CMake via Homebrew" brew install cmake
        hash -r 2>/dev/null || true
    fi
fi

if cmake_works; then
    ok "CMake $(cmake --version 2>/dev/null | head -n 1 | awk '{print $3}') at $(command -v cmake)"
else
    warn "CMake will not run on this Mac."
    warn "Kimodo will still be set up, but without the motion polish step."
    POSTPROC=no
fi

# --- 8. kimodo ---------------------------------------------------------------

step "Downloading and building Kimodo"

# One source install, not two. Installing the package and then separately
# cloning the repo for the C++ part leaves two copies of Kimodo at
# possibly different commits, with the second quietly shadowing the first.
if [ -d "$SRC" ] && [ ! -f "$SRC/setup.py" ]; then
    warn "A half-finished download was there. Starting that part again."
    rm -rf "$SRC"
fi

if [ ! -d "$SRC" ]; then
    try "Downloading source" git clone --depth 1 \
        https://github.com/nv-tlabs/kimodo.git "$SRC" \
        || die "Could not download the source." \
"Check your connection and run this installer again."
fi
[ -f "$SRC/setup.py" ] || die "The download finished but looks incomplete." \
"Delete this folder and run the installer again:
  $SRC"

# Apple's Clang is left out of the compiler's inline definition, so the
# C++ part will not build without this. Report honestly whether the patch
# actually applied — a silent no-op here surfaces as a baffling compile
# error several minutes later.
HDR="$SRC/MotionCorrection/src/cpp/Compiler.h"
if [ -f "$HDR" ]; then
    PATCH_STATUS="$(python - "$HDR" <<'PY' 2>>"$LOG"
import sys
p = sys.argv[1]
old = "#elif defined(COMPILER_GNUC)"
new = "#elif defined(COMPILER_GNUC) || defined(COMPILER_CLANG)"
s = open(p).read()
if new in s:
    print("already")
elif old in s:
    open(p, "w").write(s.replace(old, new, 1))
    print("patched" if new in open(p).read() else "failed")
else:
    print("nomatch")
PY
)"
    case "$PATCH_STATUS" in
        patched) ok "Applied the Clang compatibility patch" ;;
        already) ok "Clang compatibility patch already in place" ;;
        nomatch) warn "Clang patch not needed here — upstream has changed this file" ;;
        *)       warn "Could not apply the Clang patch. The build may still work." ;;
    esac
else
    warn "Compiler.h is not where it used to be. Skipping the Clang patch."
fi

# The C++ math code is compiled with -msse4.1 and -mavx. Those are Intel
# instruction sets; Apple Silicon's compiler does not merely ignore them,
# it refuses to compile at all. Strip them on arm64 and the same code
# builds and runs — the SIMD paths simply fall back to plain arithmetic.
if [ "$ARCH" != "x86_64" ]; then
    SIMD_RESULT="$(python - "$SRC" <<'PY' 2>>"$LOG"
import sys, os, re
root = sys.argv[1]
X86 = ["-msse4.1", "-msse4.2", "-mssse3", "-msse3", "-msse2", "-msse",
       "-mavx512f", "-mavx512", "-mavx2", "-mavx",
       "-mfma", "-mf16c", "-mpopcnt", "-mbmi2", "-mbmi", "-maes"]
changed = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in ("build", ".git", "_deps", "dist")]
    for fn in filenames:
        if fn != "CMakeLists.txt" and not fn.endswith(".cmake") and fn != "setup.py":
            continue
        path = os.path.join(dirpath, fn)
        try:
            text = open(path, encoding="utf-8").read()
        except Exception:
            continue
        original = text
        for flag in X86:
            e = re.escape(flag)
            text = re.sub(r'"' + e + r'"\s*', "", text)
            text = re.sub(r"'" + e + r"'\s*", "", text)
            text = re.sub(r"(?<![\w.=-])" + e + r"(?![\w.-])\s*", " ", text)
        text = re.sub(r"(?<![\w=-])-m(?:arch|tune)=(?:native|x86[\w.-]*|core[\w.-]*|"
                      r"haswell|skylake|broadwell|sandybridge|ivybridge|nehalem|westmere)"
                      r"(?![\w.-])\s*", "", text)
        if text != original:
            open(path, "w", encoding="utf-8").write(text)
            changed.append(os.path.relpath(path, root))
print("|".join(changed) if changed else "none")
PY
)"
    case "$SIMD_RESULT" in
        none) ok "No Intel-only compiler flags to remove" ;;
        "")   warn "Could not check for Intel-only compiler flags." ;;
        *)    ok "Removed Intel-only compiler flags from $(printf '%s' "$SIMD_RESULT" | tr '|' ' ' | wc -w | tr -d ' ') file(s)"
              printf '%s' "$SIMD_RESULT" | tr '|' '\n' | sed 's/^/      /' ;;
    esac
fi

# Removing x86 flags alone is not enough: MotionCorrection includes Intel
# intrinsic headers and types throughout its math layer. On Apple Silicon,
# use SIMDe to translate that API to ARM NEON/portable code. Intel builds keep
# the native intrinsics and are therefore unaffected.
#
# Every edit below is checked afterwards. These patches key off the shape of
# upstream's files, so if upstream reorganises them an edit can quietly do
# nothing — and a silent no-op here surfaces later as a compile failure with
# no obvious cause.
if [ "$ARCH" != "x86_64" ]; then
    ARM_PATCH_RESULT="$(python - "$SRC" <<'PY' 2>>"$LOG"
import os, sys
root = sys.argv[1]
cmake = os.path.join(root, "MotionCorrection", "CMakeLists.txt")
simd = os.path.join(root, "MotionCorrection", "src", "cpp", "Math", "SIMD.h")
scalar = os.path.join(root, "MotionCorrection", "src", "cpp", "Math", "Scalar.h")
if not all(os.path.isfile(p) for p in (cmake, simd, scalar)):
    print("missing")
    raise SystemExit

problems = []

s = open(cmake, encoding="utf-8").read()
marker = "# Kimodo macOS ARM portability patch"
if marker not in s:
    anchor = "set(CMAKE_CXX_STANDARD_REQUIRED ON)\n"
    block = '''\n# Kimodo macOS ARM portability patch\nif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)$")\n    include(FetchContent)\n    FetchContent_Declare(\n        simde\n        GIT_REPOSITORY https://github.com/simd-everywhere/simde.git\n        GIT_TAG v0.8.2\n        GIT_SHALLOW TRUE\n    )\n    FetchContent_MakeAvailable(simde)\nendif()\n'''
    s = s.replace(anchor, anchor + block, 1)
    anchor = "    ${CMAKE_CURRENT_SOURCE_DIR}/src/cpp\n)\n"
    block = '''\nif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)$")\n    target_include_directories(motion_correction_cpp_base PUBLIC ${simde_SOURCE_DIR})\n    target_compile_definitions(motion_correction_cpp_base PUBLIC\n        MOTION_CORRECTION_USE_SIMDE=1 SIMDE_ENABLE_NATIVE_ALIASES=1)\nendif()\n'''
    s = s.replace(anchor, anchor + block, 1)
    s = s.replace("if(MSVC)\n", 'if(MSVC AND NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)$")\n', 1)
    open(cmake, "w", encoding="utf-8").write(s)
s = open(cmake, encoding="utf-8").read()
if "FetchContent_MakeAvailable(simde)" not in s:
    problems.append("cmake-fetch")
if "MOTION_CORRECTION_USE_SIMDE" not in s:
    problems.append("cmake-define")

s = open(simd, encoding="utf-8").read()
if "MOTION_CORRECTION_USE_SIMDE" not in s:
    s = s.replace("#include <immintrin.h>", '''#if defined(MOTION_CORRECTION_USE_SIMDE)\n#  if !defined(SIMDE_ENABLE_NATIVE_ALIASES)\n#    define SIMDE_ENABLE_NATIVE_ALIASES\n#  endif\n#  include <simde/x86/avx.h>\n#  include <simde/x86/sse4.1.h>\n#else\n#  include <immintrin.h>\n#endif''', 1)
    open(simd, "w", encoding="utf-8").write(s)
s = open(simd, encoding="utf-8").read()
if "simde/x86/sse4.1.h" not in s:
    problems.append("simd-header")

s = open(scalar, encoding="utf-8").read()
if "#include <cstdlib>" not in s:
    if "#include <stdint.h>" in s:
        s = s.replace("#include <stdint.h>", "#include <stdint.h>\n#include <cstdlib>", 1)
    elif "#pragma once" in s:
        s = s.replace("#pragma once", "#pragma once\n#include <cstdlib>", 1)
    else:
        s = "#include <cstdlib>\n" + s
s = s.replace("return (int8_t) abs( a );", "return (int8_t) std::abs( (int) a );")
s = s.replace("return (int16_t) abs( a );", "return (int16_t) std::abs( (int) a );")
s = s.replace("return labs( a );", "return std::abs( a );")
s = s.replace("return llabs( a );", "return std::abs( a );")
open(scalar, "w", encoding="utf-8").write(s)
s = open(scalar, encoding="utf-8").read()
if "#include <cstdlib>" not in s:
    problems.append("scalar-include")
if "labs(" in s.replace("std::abs(", ""):
    problems.append("scalar-abs")

print("ok" if not problems else "partial:" + ",".join(problems))
PY
)"
    case "$ARM_PATCH_RESULT" in
        ok)
            ok "Enabled ARM-compatible SIMD translation"
            info "The C++ build will fetch SIMDe v0.8.2 from GitHub."
            ;;
        missing)
            warn "MotionCorrection sources moved; ARM patch was not applied"
            ;;
        partial:*)
            warn "The ARM patch only partly applied: ${ARM_PATCH_RESULT#partial:}"
            warn "Upstream has changed the shape of these files, so the C++"
            warn "build will probably fail. Everything else still works."
            warn "Please send $LOG to $SUPPORT so we can update the patch."
            ;;
        *)
            warn "Could not apply the ARM compatibility patch"
            ;;
    esac
fi

info "Installing Kimodo and everything it needs, and compiling the C++"
info "part. This goes quiet for a while. That is normal."
printf '\n'

# The [all] extra is what brings in the interactive demo's dependencies.
# Without it, kimodo_demo installs but will not start.
#
# SKIP_MOTION_CORRECTION_IN_SETUP=1 is deliberate and matches NVIDIA's own
# Dockerfile: the C++ module is NOT built as a side effect of the main
# install. Bundled that way it compiles but often does not end up
# importable under an editable install, and the failure only shows up
# much later, mid-generation. Step 10 installs it properly instead.
if ( cd "$SRC" && env SKIP_MOTION_CORRECTION_IN_SETUP=1 \
        python -m pip install -e ".[all]" ) >>"$LOG" 2>&1; then
    ok "Kimodo installed"
else
    warn "That install failed. Trying once more."
    if ( cd "$SRC" && env SKIP_MOTION_CORRECTION_IN_SETUP=1 \
            python -m pip install -e ".[all]" ) >>"$LOG" 2>&1; then
        ok "Kimodo installed"
    else
        die "Kimodo would not install." \
"If the log mentions 'no matching distribution' for torch, this Mac is an
Intel model and something in Kimodo now requires a PyTorch newer than
Apple ever shipped for Intel. That cannot be worked around locally.

Otherwise, send the log to ${BRAND}: ${SUPPORT}"
    fi
fi

python -c "import kimodo" >/dev/null 2>&1 \
    || die "Kimodo installed but won't load." "Send the log to ${BRAND}: ${SUPPORT}"

# On Intel, Kimodo ships a transformers release that expects a PyTorch
# newer than Apple ever built for Intel. Step it back. This is done after
# the install, deliberately: as a pip constraint it would make the whole
# resolution fail instead.
if [ "$PIN" = yes ]; then
    TF="$(python -c 'import transformers;print(transformers.__version__)' 2>/dev/null)"
    case "$TF" in
        4.46.*) ok "transformers already at $TF" ;;
        *)
            info "Kimodo ships a transformers release that wants a newer PyTorch"
            info "than Intel Macs can run. Stepping it back one version."
            try "Adjusting transformers" python -m pip install "transformers==4.46.3" \
                || die "Could not adjust transformers."
            ;;
    esac
    python -c "import kimodo" >/dev/null 2>&1 \
        || die "Kimodo stopped loading after the transformers change." \
"Send the log to ${BRAND}: ${SUPPORT}"
fi
ok "Kimodo ready"

# --- 9. viewer ---------------------------------------------------------------

step "Installing the 3D viewer"

# This must come after Kimodo: the [all] extra pulls in the public viser
# from PyPI, and NVIDIA's fork has to end up on top of it.
if python -c "from viser import _timeline_api" >/dev/null 2>&1; then
    ok "Already installed"
else
    python -m pip uninstall -y viser >>"$LOG" 2>&1
    try "Downloading the viewer" python -m pip install \
        "git+https://github.com/nv-tlabs/kimodo-viser.git" \
        || die "The 3D viewer would not install." "Send the log to ${BRAND}: ${SUPPORT}"
    python -c "from viser import _timeline_api" >/dev/null 2>&1 \
        || die "The viewer installed but is missing pieces Kimodo needs." \
"This usually means the public viser package got installed instead of
NVIDIA's. Run the installer again."
    ok "Viewer ready"
fi

# --- 10. motion polish + version lock ----------------------------------------

step "Motion polish and version check"

# MotionCorrection is a standalone package with its own setup, and
# upstream documents installing it on its own: "pip install ." from that
# directory. Non-editable, so the compiled extension lands in
# site-packages where Python will actually find it.
MC="$SRC/MotionCorrection"

if [ "$POSTPROC" = yes ]; then
    if python -c "import motion_correction" >/dev/null 2>&1; then
        ok "Motion polish module already installed"
    elif [ ! -d "$MC" ]; then
        warn "MotionCorrection is not in the source tree. Upstream moved it."
        POSTPROC=no
    else
        info "Compiling the motion polish module. A few minutes, and it"
        info "fetches a couple of small C++ libraries while it works."
        rm -rf "$MC/build" 2>/dev/null
        ( cd "$MC" && python -m pip install . ) >>"$LOG" 2>&1

        if python -c "import motion_correction" >/dev/null 2>&1; then
            ok "Motion polish module built and importable"
        else
            info "Retrying without build isolation."
            rm -rf "$MC/build" 2>/dev/null
            ( cd "$MC" && python -m pip install . --no-build-isolation ) >>"$LOG" 2>&1
            if python -c "import motion_correction" >/dev/null 2>&1; then
                ok "Motion polish module built and importable"
            else
                POSTPROC=no
            fi
        fi
    fi
fi

# Kimodo Studio turns post-processing ON by default and there is no flag
# to change that, so without this module the app crashes the moment you
# press Generate. A shortcut that always crashes is worse than no
# shortcut, so when this fails Studio is not offered at all.
if [ "$POSTPROC" = no ]; then
    printf '\n'
    warn "The motion polish module could not be built on this Mac."
    warn ""
    warn "Kimodo Studio needs it and cannot be told to skip it."
    warn ""
    warn "Both Desktop shortcuts will try to build it again by themselves"
    warn "the first time you open them, so this may still sort itself out."
    warn "If it does not, New Motion falls back automatically and keeps"
    warn "working; only Studio will decline to start."
    warn ""
    warn "If it keeps failing, send $LOG to $SUPPORT"
    printf '\n'
fi

# Nothing installed above should have moved the Intel pins, but check
# rather than assume — a silent NumPy 2 here breaks generation in a way
# that reads like a Kimodo bug.
if [ "$PIN" = yes ]; then
    if ! python -c "import numpy, sys; sys.exit(0 if numpy.__version__ < '2' else 1)" 2>/dev/null; then
        warn "Something raised NumPy above 2. Putting it back."
        try "Restoring NumPy" python -m pip install "numpy<2" \
            || die "Could not restore NumPy."
    fi
    case "$(python -c 'import transformers;print(transformers.__version__)' 2>/dev/null)" in
        4.46.*) ;;
        *)
            warn "Something moved transformers again. Putting it back."
            try "Restoring transformers" python -m pip install "transformers==4.46.3" \
                || die "Could not restore transformers."
            ;;
    esac
    ok "Intel version pins verified"
else
    ok "No version pins needed on Apple Silicon"
fi

# --- 11. verify --------------------------------------------------------------

step "Checking everything works"

MISSING=""
check() {  # check "label" python-import-or-command
    if eval "$2" >/dev/null 2>&1; then
        ok "$1"
    else
        fail "$1"
        MISSING="$MISSING
    $1"
    fi
}

check "Kimodo loads"          'python -c "import kimodo"'
check "PyTorch loads"         'python -c "import torch"'
check "NumPy and PyTorch agree" 'python -c "import torch, numpy; torch.from_numpy(numpy.zeros(1))"'
check "3D viewer loads"        'python -c "from viser import _timeline_api"'
check "Node.js runs"           'node --version'
check "Generator on PATH"      'command -v kimodo_gen'
check "Studio on PATH"         'command -v kimodo_demo'
check "Studio interface loads"  'python -c "import gradio, gradio_client"'

if [ "$POSTPROC" = yes ]; then
    check "Motion polish loads" 'python -c "import motion_correction"'
else
    info "Motion polish — skipped on purpose"
fi

if [ -n "$MISSING" ]; then
    die "Some pieces are still missing:$MISSING" \
"Run this installer again — it retries only what's missing. If the same
things fail twice, send the log to ${BRAND}: ${SUPPORT}"
fi

# --- 12. first run -----------------------------------------------------------

if [ "$AWAITING" = yes ] && ! can_reach_gated; then
    step "Waiting on Meta"
    cat <<EOF

  ${YEL}Everything is installed and checked. The only thing left is${R}
  ${YEL}Meta's approval for the language model.${R}

  Watch for the email, or check here:
    https://huggingface.co/settings/gated-repos

  When it says ACCEPTED, ${B}open this installer again${R}. It skips
  everything you've already done and goes straight to generating
  your first motion.

EOF
    finish 0
fi

step "First generation"

GEN_FLAGS=""
[ "$POSTPROC" = no ] && GEN_FLAGS="--no-postprocess"

CACHED=no
[ -d "$HOME/.cache/huggingface/hub/models--meta-llama--Meta-Llama-3-8B-Instruct" ] && CACHED=yes

if [ "$CACHED" = yes ]; then
    info "The models are already on this Mac, so nothing downloads now."
else
    info "The language model downloads first. About 16 GB, once and never again."
fi
cat <<'NOTE'

  Your Mac now generates a three-second walk cycle to prove the whole
  chain works. This runs on the processor, so it can take a while —
  how long depends on your Mac. The fan will spin up. That's the point.

  Two messages will scroll past that look like faults and are not:

    "Text encoder service is unreachable, falling back to local
     LLM2Vec encoder"  — correct. That service is for NVIDIA server
     setups. Your Mac reads prompts locally instead.

    Warnings about peft_config and torch.tensor — noise from the
     libraries Kimodo uses. Nothing to do about them.

  Do not close this window. It is not stuck.

NOTE

# --output takes a stem, not a filename: pass "…/name" and Kimodo writes
# "…/name.npz" itself. Passing "…/name.npz" produces "name.npz.npz", and
# the check below would then report a perfectly good run as a failure.
STEM="$DESKTOP/kimodo-first-motion"
OUT="$STEM.npz"
rm -f "$OUT" 2>/dev/null

# shellcheck disable=SC2086
TEXT_ENCODER_DEVICE=cpu kimodo_gen "a person walks forward" \
    --duration 3 --output "$STEM" $GEN_FLAGS 2>&1 | tee -a "$LOG"

if [ ! -f "$OUT" ]; then
    fail "Generation didn't produce a file."
    cat <<EOF

  Everything is installed and verified; only this last step failed.
  The three usual causes:

    ${B}Killed: 9${R}      this Mac ran out of memory. Close every other
                   app, including the browser, and open the installer
                   again. On a Mac with less than ${RAM_TIGHT} GB this may
                   not succeed at all.
    ${B}gated / 403${R}    Meta's approval hasn't landed. Check
                   https://huggingface.co/settings/gated-repos
    ${B}connection${R}     the 16 GB model download was interrupted. Just
                   open the installer again; it resumes.

  ${DIM}Log: $LOG${R}
EOF
    finish 1
fi

python - "$OUT" <<'PY'
import sys, numpy as np
with np.load(sys.argv[1]) as d:
    t, j = d["global_rot_mats"].shape[:2]
    print("\n  %d frames, %d joints" % (t, j))
PY

# --- launchers ---------------------------------------------------------------

POSTNOTE=""
[ "$POSTPROC" = no ] && POSTNOTE='echo "Note: switch Post Processing OFF in the app — it is not built on this Mac."'

cat > "$DESKTOP/Kimodo Studio.command" <<LAUNCH
#!/usr/bin/env bash
# Kimodo Studio — opens Kimodo in your web browser.
# NVIDIA Kimodo, set up for macOS by $BRAND (v$VERSION).
# $COPYRIGHT
# $LICENSE_LINE
# Questions? $SUPPORT

source "$VENV/bin/activate" || {
    echo "The Kimodo environment is missing. Run the installer again."
    read -r _; exit 1
}

if [ -d "$NODEENV/bin" ]; then PATH="$NODEENV/bin:\$PATH"; export PATH; fi

CA="\$(python -m certifi 2>/dev/null)"
if [ -n "\$CA" ] && [ -f "\$CA" ]; then
    export SSL_CERT_FILE="\$CA"
    export REQUESTS_CA_BUNDLE="\$CA"
    export NODE_EXTRA_CA_CERTS="\$CA"
fi

export TEXT_ENCODER_DEVICE=cpu
export PYTORCH_ENABLE_MPS_FALLBACK=1
MC="$MC"

# Kimodo Studio turns post-processing on by default and offers no way to
# switch it off from here, so without this module it crashes the moment
# you press Generate. Check before starting, and try to fix it rather
# than handing you an error you have to look up.
if ! python -c "import motion_correction" >/dev/null 2>&1; then
    echo "The motion polish module is missing. Kimodo Studio needs it."
    echo "Building it now — a few minutes, then Studio starts by itself."
    echo
    if [ -d "$MC" ]; then
        # A CMake wrapper on PATH can look fine and still fail inside
        # pip's build environment, so test that it runs, and reach for
        # the real binary the Python package ships.
        cmake --version >/dev/null 2>&1 || python -m pip install --upgrade cmake >>"$LOG" 2>&1
        CMB="\$(python -c 'import cmake, os
print(os.path.join(os.path.dirname(cmake.__file__), "data", "bin"))' 2>/dev/null)"
        if [ -n "\$CMB" ] && [ -x "\$CMB/cmake" ]; then
            PATH="\$CMB:\$PATH"; export PATH
        fi
        rm -rf "$MC/build" 2>/dev/null
        python -m pip install "$MC" >>"$LOG" 2>&1
    fi
    if python -c "import motion_correction" >/dev/null 2>&1; then
        echo "Fixed. Carrying on."
        echo
    else
        echo
        echo "It would not build on this Mac, and Kimodo Studio would"
        echo "crash as soon as you pressed Generate, so it will not be"
        echo "started."
        echo
        echo "Use the New Motion shortcut instead — it works without this"
        echo "module, with slightly more foot sliding."
        echo
        echo "Send this file to $BRAND: $SUPPORT"
        echo "  $LOG"
        echo
        echo "Press return to close."
        read -r _
        exit 1
    fi
fi

if nc -z 127.0.0.1 7860 >/dev/null 2>&1; then
    echo "Something is already using port 7860."
    echo "Kimodo Studio may already be running — try http://localhost:7860"
    echo
fi

echo "Kimodo Studio  —  NVIDIA Kimodo, packaged for Mac by $BRAND"
echo
echo "Starting Kimodo. The browser opens by itself in a moment."
echo "Loading the model takes a few minutes the first time each day."
echo "Leave this window open while you work. Press Control-C to stop."
$POSTNOTE
echo

(
  for _ in \$(seq 1 900); do
    if nc -z 127.0.0.1 7860 >/dev/null 2>&1; then
      sleep 2; open "http://localhost:7860"; exit 0
    fi
    sleep 1
  done
) &
WATCHER=\$!

kimodo_demo

kill "\$WATCHER" 2>/dev/null
echo
echo "Kimodo Studio has stopped. Press return to close."
read -r _
LAUNCH
chmod +x "$DESKTOP/Kimodo Studio.command"

cat > "$DESKTOP/New Motion.command" <<LAUNCH
#!/usr/bin/env bash
# New Motion — asks for a description and writes an .npz to the Desktop.
# NVIDIA Kimodo, set up for macOS by $BRAND (v$VERSION).
# $COPYRIGHT
# $LICENSE_LINE
# Questions? $SUPPORT

source "$VENV/bin/activate" || {
    echo "The Kimodo environment is missing. Run the installer again."
    read -r _; exit 1
}

if [ -d "$NODEENV/bin" ]; then PATH="$NODEENV/bin:\$PATH"; export PATH; fi

# The same certificate wiring the installer used. Without it, any model
# this Mac has not downloaded yet fails with an SSL error.
CA="\$(python -m certifi 2>/dev/null)"
if [ -n "\$CA" ] && [ -f "\$CA" ]; then
    export SSL_CERT_FILE="\$CA"
    export REQUESTS_CA_BUNDLE="\$CA"
    export NODE_EXTRA_CA_CERTS="\$CA"
fi

export TEXT_ENCODER_DEVICE=cpu
export PYTORCH_ENABLE_MPS_FALLBACK=1
MC="$MC"

# Decided here rather than baked in when this file was written, so a
# module built (or lost) later is picked up on the next run.
EXTRA=""
if ! python -c "import motion_correction" >/dev/null 2>&1; then
    echo "Motion polish module missing. Trying to build it, a few minutes."
    if [ -d "$MC" ]; then
        # A CMake wrapper on PATH can look fine and still fail inside
        # pip's build environment, so test that it runs, and reach for
        # the real binary the Python package ships.
        cmake --version >/dev/null 2>&1 || python -m pip install --upgrade cmake >>"$LOG" 2>&1
        CMB="\$(python -c 'import cmake, os
print(os.path.join(os.path.dirname(cmake.__file__), "data", "bin"))' 2>/dev/null)"
        if [ -n "\$CMB" ] && [ -x "\$CMB/cmake" ]; then
            PATH="\$CMB:\$PATH"; export PATH
        fi
        rm -rf "$MC/build" 2>/dev/null
        python -m pip install "$MC" >>"$LOG" 2>&1
    fi
    if python -c "import motion_correction" >/dev/null 2>&1; then
        echo "Fixed."
    else
        EXTRA=" --no-postprocess"
        echo "Could not build it. Generating without foot-slide cleanup."
        echo "The motion is still fine, feet may drift a little."
    fi
    echo
fi

echo
echo "New Motion  —  NVIDIA Kimodo, packaged for Mac by $BRAND"
echo
echo "Describe the motion, then press return."
echo "For example: a person runs and jumps over a low wall"
echo
printf "Prompt: "
read -r PROMPT
if [ -z "\$PROMPT" ]; then echo "Nothing entered."; sleep 2; exit 1; fi

printf "Seconds [5]: "
read -r SECS
[ -z "\$SECS" ] && SECS=5
case "\$SECS" in
    ''|*[!0-9.]*) echo "That is not a number. Using 5 seconds."; SECS=5 ;;
esac

NAME=\$(printf '%s' "\$PROMPT" | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)
[ -z "\$NAME" ] && NAME="motion"
STEM="$DESKTOP/\$NAME-\$(date +%H%M%S)"

echo
echo "Generating. This can take a while and goes quiet. Not stuck."
echo
# shellcheck disable=SC2086
kimodo_gen "\$PROMPT" --duration "\$SECS" --output "\$STEM" \$EXTRA
echo
if [ -f "\$STEM.npz" ]; then
    echo "Saved to the Desktop as \$(basename "\$STEM").npz"
else
    echo "That didn't produce a file. Details are in:"
    echo "  $LOG"
    echo "If it keeps happening, write to $BRAND: $SUPPORT"
fi
echo "Press return to close."
read -r _
LAUNCH
chmod +x "$DESKTOP/New Motion.command"

POLISH_LINE="    Motion polish     on"
STUDIO_LINE="    Kimodo Studio     opens the app in your browser at localhost:7860"
if [ "$POSTPROC" = no ]; then
    POLISH_LINE="    Motion polish     off (shortcuts will retry the build on first run)"
fi

cat <<EOF

  ${GRN}${B}Done. Everything installed and checked.${R}

  ${B}Your first motion file is on the Desktop:${R}
    kimodo-first-motion.npz

  Drag it into Blender with KnitMotion and it lands in your
  Load Actions list, ready for a Mixamo rig in one click.

  ${B}Two shortcuts are on your Desktop as well:${R}

$STUDIO_LINE
    New Motion        asks for a description, writes a file

  ${B}This install:${R}
$POLISH_LINE

  ${DIM}Double-click either shortcut. They're yours now, so macOS won't
  question them the way it questioned this installer.${R}

  ${DIM}----------------------------------------------------------------${R}
  Motion model by ${B}NVIDIA${R} (Kimodo). Mac installer by ${B}${BRAND}${R} v${VERSION}.
  Questions, or anything not right? We'd like to hear from you:
  ${B}${SUPPORT}${R}
  ${DIM}If something failed, attaching ${LOG} helps.${R}

  ${DIM}${COPYRIGHT}
  ${LICENSE_LINE}${R}

EOF

if [ "$POSTPROC" = no ]; then
    cat <<EOF
  ${DIM}Not opening Kimodo Studio now, because the motion polish module
  it needs would not build. Double-click "Kimodo Studio" on your
  Desktop whenever you like — it tries the build once more before
  it starts, and tells you plainly if it cannot.${R}

EOF
    finish 0
fi

head2 "Opening Kimodo Studio"

cat <<EOF
  Kimodo Studio runs on this Mac and opens in your browser at
  ${B}http://localhost:7860${R} — nothing goes over the internet.

  It loads the model first, which takes a few minutes, then the
  browser opens by itself.

EOF

OPENIT=""
if have_tty; then
    printf '  Open it now? Press %sreturn%s for yes, or type %sno%s: ' "$B" "$R" "$B" "$R"
    read -r OPENIT < /dev/tty
fi

case "$OPENIT" in
    [Nn]|[Nn][Oo])
        cat <<EOF

  ${DIM}Whenever you want it: double-click "Kimodo Studio" on your Desktop.
  It opens http://localhost:7860 in your browser by itself.${R}

EOF
        finish 0
        ;;
esac

if nc -z 127.0.0.1 7860 >/dev/null 2>&1; then
    warn "Something is already using port 7860."
    warn "If Kimodo Studio is already open, try http://localhost:7860"
fi

cat <<EOF

  ${DIM}Loading. The browser opens by itself when it's ready.${R}
  ${DIM}Leave this window open while you work. Press Control-C to stop.${R}

EOF

(
  for _ in $(seq 1 900); do
    if nc -z 127.0.0.1 7860 >/dev/null 2>&1; then
      sleep 2
      open "http://localhost:7860" 2>/dev/null
      exit 0
    fi
    sleep 1
  done
) &
WATCHER=$!

TEXT_ENCODER_DEVICE=cpu kimodo_demo

kill "$WATCHER" 2>/dev/null

cat <<EOF

  ${DIM}Kimodo Studio has stopped. To start it again, just double-click
  "Kimodo Studio" on your Desktop.${R}

EOF
finish 0
