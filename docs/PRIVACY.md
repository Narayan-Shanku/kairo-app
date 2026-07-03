# Kairō — Privacy Policy

_Last updated: July 2, 2026_

Kairō is built privacy-first. **Your memory store lives on your iPhone and is
never uploaded.** On iPhones with Apple Intelligence, everything — including AI
answers — runs entirely on-device. On iPhones without Apple Intelligence, only
the few memory snippets needed to answer a question are sent, over an encrypted
connection, to our answer service — and you can turn that off.

## The short version
- **No accounts. No sign-in. No tracking. No ads. No analytics.**
- Everything you capture — voice notes, text, transcripts, answers, review
  cards — is stored **entirely on your iPhone**. Your memory store is never
  uploaded or backed up to us.
- **Apple Intelligence iPhones:** answers are generated on-device. Nothing
  leaves your phone.
- **Other iPhones:** to write an answer, Kairō sends *only* the handful of
  memory snippets relevant to your question (plus the question) to our answer
  service. Nothing is stored there, and you can switch this off in Settings —
  Kairō then stays fully on-device.

## What Kairō stores, and where
All of the following is kept **locally on your device** and is never uploaded:
- Your check-ins (text and transcribed voice notes)
- The AI-generated answers, review cards, and weekly digests derived from them
- Usage state such as streaks and review schedules

Deleting the app removes all of this data from your device.

## How answers are generated
When you ask Kairō a question (or open your weekly digest), it first searches
your memories **on your device** and picks the few snippets that matter.

- **On iPhones that support Apple Intelligence,** the answer is then written by
  Apple's on-device Foundation Models. Your data never leaves the phone.
- **On iPhones that don't,** Kairō sends those few snippets and your question
  over HTTPS to our stateless answer service, which uses Anthropic's Claude API
  to write the answer. What's sent: the retrieved snippets and the question —
  **never your full memory store**, and never any account or identity (there are
  no accounts). Our service keeps no copy and no logs of your content, and
  content sent to the Claude API is not used to train AI models.
- **Your choice:** Settings → "Use private cloud for answers" turns this off.
  Kairō then runs fully on-device and shows your most relevant memories instead
  of a written answer.

## Microphone & Speech Recognition
- The **microphone** is used only while you are recording a voice check-in.
- Audio is **transcribed on your device** using Apple's on-device Speech
  Recognition. Your recordings are never uploaded.

## Health-related information
Some notes you write may relate to your health (food, sleep, symptoms, etc.).
Like all memories, they are stored only on your device. If you ask a question
they're relevant to on a non-Apple-Intelligence iPhone with cloud answers on,
those snippets may be included in the answer request described above — turn the
toggle off if you'd rather they never leave the device.

## Data we collect about you
Kairō has no accounts, no analytics, and no tracking, and we operate no
database of users or content. The only data that ever leaves your device is the
per-question snippet transmission described above, which is processed to
generate your answer and not retained by us.

## Third parties
Kairō contains no advertising, analytics, or tracking SDKs. For cloud answers
on non-Apple-Intelligence devices, two infrastructure providers process the
per-question request in transit: Cloudflare (hosts our stateless answer
service) and Anthropic (the Claude API that writes the answer, which does not
train on this content). Neither receives your name, account, or full memory
store.

## Children
Kairō is not directed at children under 13.

## Changes
If this policy changes, the updated version will be posted here with a new date.

## Contact
Questions about privacy? Contact: privacy@kairo.app
