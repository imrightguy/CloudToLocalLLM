# Voice Conversation System

Status: avatar companion foundation

Voice is part of the avatar companion, not a standalone app feature. This document describes the voice layer that should attach to the avatar sidecar window and the secure agent channel.

## Goal

Make the CloudToLocalLLM avatar feel like a natural local voice companion instead of a push-to-talk tool or delayed assistant loop.

The target experience is:
- always listening locally
- fast direct acknowledgement when Christopher addresses Zoidbot
- short conversational back-and-forth without re-entering a heavy analysis loop every turn
- optional escalation to deeper Hermes reasoning, vision, or desktop-aware context when useful

## Why an avatar sidecar helps

A dedicated avatar/voice sidecar is a better fit for natural conversation than bolting voice directly onto Hermes because it can own:
- microphone stream handling
- wake-word or direct-address detection
- turn-taking / end-of-utterance detection
- barge-in behavior
- local playback and interruption control
- lightweight conversational state

Hermes remains the brain for:
- tools
- memory
- desktop awareness
- long-context reasoning
- agent actions

The avatar companion becomes the low-latency voice shell around Hermes or the selected agent runtime.

## Recommended architecture

### 1. Audio input layer

Responsibilities:
- capture continuous microphone audio
- maintain a rolling short buffer
- feed low-latency wake/direct-address detection
- feed STT only when speech or engagement conditions are met

Preferred shape:
- streaming microphone capture, not fixed long chunks
- 200–500 ms processing cadence
- VAD before full STT where possible

## 2. Wake/direct-address layer

Preferred options:
- openWakeWord for explicit wake phrases
- fallback direct-address heuristics from partial transcript

Why:
- this separates stream/background audio from user-directed speech
- this is the main fix for “the assistant hears sound but does not know I’m talking to it”

## 3. Turn manager

Responsibilities:
- determine whether the system is idle, listening, engaged, speaking, or cooling down
- keep a short conversational hold window after a successful wake or reply
- prefer lightweight conversational replies during that hold window
- only escalate to heavier reasoning when needed

## 4. Reply planner

Three reply lanes:

1. fast acknowledgement
   - examples: “Yeah?”, “I’m here.”, “Go on.”
   - should feel near-instant

2. conversational local reply
   - short natural answer
   - low latency
   - should avoid tool-heavy reasoning by default

3. deep routed reply
   - use Hermes / router / providers / desktop context / memory when the user is asking something that actually needs it

## 5. Output / TTS layer

Requirements:
- fast start
- interruptible playback
- short response-first behavior
- optional streaming TTS later

## MVP to build next

### Phase A — foundation
- voice conversation state service
- engagement hold window
- fast acknowledgement path
- local transcript-first conversational mode

### Phase B — real input pipeline
- microphone streaming adapter
- VAD gate
- wake-word integration via openWakeWord
- partial transcript handling

### Phase C — natural turn-taking
- interrupt current playback when the user starts speaking
- partial STT updates
- end-of-utterance detection
- response cancellation / replacement

### Phase D — sidecar polish
- visible voice status orb / indicator
- transcript preview
- “hearing / engaged / speaking” state
- compact desktop-aware context handoff to Hermes
- optional avatar reaction sync

## Repo implementation notes

Current foundation added in repo:
- `lib/services/voice/voice_conversation_service.dart`

This service provides:
- `VoiceConversationMode`
- engagement hold window
- direct-address heuristics
- fast acknowledgement suggestions
- assistant reply/session state tracking

This is intentionally dependency-light so it can be wired into the avatar companion before committing to a specific mic/STT package.

## Suggested next code steps

1. Add desktop-only mic adapter service
   - Linux first
   - streaming capture instead of long ffmpeg chunks

2. Add explicit wake-word package/integration
   - openWakeWord service or sidecar

3. Add a minimal voice debug panel
   - current mode
   - last transcript
   - last reply
   - engaged-until timer

4. Route conversational replies through Hermes only when needed
   - keep acknowledgements local and fast
   - escalate selectively

## Practical recommendation

Yes: CloudToLocalLLM as the avatar/voice sidecar makes this easier.

Best split:
- Avatar companion = natural voice shell and side presence
- Main app = secure channel, setup, management, approvals
- Hermes/selected agent runtime = memory, tools, desktop awareness, deep reasoning

That division keeps the main app simple while giving the assistant a persistent desktop presence.
