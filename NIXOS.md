# NixOS / Nomad adaptation notes

This fork adapts the upstream Fountain skills to a NixOS host that manages its
own software. The upstream skills assume a developer machine where the agent
can install packages on demand. That assumption does not hold here, so the
differences are listed below.

Everything not listed here is unchanged from
`fountain-fm/fountain-skills`, and `LICENSE` and the per-asset licences still
apply.

## Why this fork exists

1. Self-installation is not possible or desirable. Software comes from Nix.
2. Word-level transcription comes from the host's Faster-Whisper service, not
   from an ffmpeg `whisper` filter and a whisper.cpp model file.
3. The agent must not create a durable wrapper script around the Fountain API.
   This host treats repo-backed wrappers as the source of truth.

## Software policy

Do not install packages. The host provides everything the skills need:

| Need | Provided by |
| --- | --- |
| `ffmpeg` / `ffprobe` | host `ffmpeg` (libass, drawtext, fontconfig) |
| OpenCV 4.8+ | host `video-editing` Python environment |
| `yt-dlp` | host `yt-dlp` |
| ImageMagick | host `imagemagick` |
| Word timings | host Faster-Whisper service on `127.0.0.1:8766` |

If a tool is missing, report it. Do not install it and do not fall back to a
Homebrew, `apt`, or `pip install` command. Missing software is an operator
decision, not an agent decision.

## Transcription and word timings

Upstream expects an ffmpeg build that carries the `whisper` filter plus a
whisper.cpp model in `~/.cache/whisper`. This host runs neither. Upstream also
warns that an ffmpeg with the filter but no model hangs silently instead of
failing, which is a poor property for an unattended run.

Instead, request word timings from the host Faster-Whisper service:

```bash
curl -s -X POST http://127.0.0.1:8766/v1/transcriptions \
  -H 'Content-Type: application/json' \
  -d '{"audio_path":"/absolute/clip.wav","language":"en","word_timestamps":true}'
```

The response keeps the existing `text` and `segments` fields and adds `words`,
a list of `{"word","start","end"}` objects. That is the shape the caption
builder reads, so `build-captions.py` and `plan-shots.py` consume it directly.

Request `word_timestamps` only when word-level data is actually needed. Word
alignment costs extra work that the segment-only callers do not want.

The service also reports `speaker` on nothing: it does not diarize. For
multi-speaker shot planning, derive speakers another way and say so, rather
than assuming a field the service never sends.

Check the service before a run that depends on it:

```bash
curl -s http://127.0.0.1:8766/healthz
```

A `"busy": true` response means another transcription holds the model. Wait
rather than starting a competing job.

## Durable API wrappers

Upstream tells the agent to write throwaway scripts for repetitive requests
and never to keep a script that wraps the API. This host disagrees with the
second half of that rule.

A thin wrapper that this host owns, versions, and tests is more durable than a
throwaway script, because it survives the agent that wrote it and it can be
verified. Write a wrapper in the host repository when a task needs repeated
API calls. Delete genuinely one-off scratch work.

The rule that the agent must not approve, schedule, or publish on its own
still applies, and it applies to wrappers too. Drafts only.

## Upstream

```bash
git remote add upstream https://github.com/fountain-fm/fountain-skills.git
git fetch upstream
git rebase upstream/main
```

Review the diff before pushing. Upstream moves often, and the files this fork
edits are heavily edited upstream.