# Murmur — Full Engineering Specification
### Voice Dictation & Intelligent Notes for Unconventional Psychotherapy

**Version:** 1.0 Draft
**Date:** March 19, 2026
**Status:** Requirements & Design Specification
**License:** Open Source (TBD)
**Distribution:** Unlisted App Store (private, employees only)

---

**Table of Contents**

1. [Executive Summary](#1-executive-summary)
2. [Product Overview](#2-product-overview)
3. [User Personas](#3-user-personas)
4. [Feature Specifications](#section-4-feature-specifications)
5. [User Stories & Acceptance Criteria](#section-5-user-stories--acceptance-criteria)
6. [Architecture & System Design](#section-6-architecture--system-design)
7. [Data Model & Schema](#section-7-data-model--schema)
8. [API & Interface Contracts](#section-8-api--interface-contracts)
9. [UI/UX Specifications](#section-9-uiux-specifications)
10. [Platform-Specific Requirements](#section-10-platform-specific-requirements)
11. [Accessibility Specification](#section-11-accessibility-specification)
12. [Security & Privacy](#section-12-security--privacy)
13. [Testing Strategy](#section-13-testing-strategy)
14. [CI/CD & Build](#section-14-cicd--build)
15. [Roadmap & Phasing](#section-15-roadmap--phasing)
16. [Appendices](#section-16-appendices)

---

## 1. Executive Summary

Murmur is an open-source voice dictation and intelligent notes application for macOS 26+ and iOS, built for the team at Unconventional Psychotherapy. It delivers the full capability set of commercial tools like Wispr Flow — system-wide voice-to-text at up to 4x typing speed, AI-powered editing, multilingual support, and seamless text injection into any application — while adding a first-class, built-in notes and organization system that commercial dictation tools have consistently neglected. Murmur is built natively in Swift and SwiftUI, leverages Apple's on-device SpeechAnalyzer framework for privacy-preserving transcription, and exposes a pluggable cloud AI layer for enhanced editing, summarization, or custom model support. The app is distributed privately via an unlisted App Store listing to 2–10 employees, with the source code published openly under a permissive license.

### Product Vision

The vision is a single, unified tool where speaking is the primary input modality for everything: composing emails, writing code, capturing meeting notes, drafting documents, and building a personal knowledge base. Users should never have to choose between a capable dictation tool and a capable notes app. Murmur collapses that distinction entirely. Every dictation session is a first-class note that can be organized, searched, tagged, linked, and exported — or silently discarded into whatever third-party application the user is focused on, exactly as they would expect from a Wispr Flow-style flow-through dictation experience.

### Target Audience

Murmur is built primarily for the 2–10 employees at Unconventional Psychotherapy who produce written output as part of their daily work: session notes, client communications, internal documentation, and administrative writing. The open-source codebase is also suitable for any professional or team who produces large volumes of written output and values privacy-preserving, on-device transcription.

### Key Differentiators vs. Wispr Flow

Wispr Flow is a polished, well-funded commercial product with strong dictation fundamentals. Its weaknesses are deliberate: it has no persistent note storage, no organization layer, no export pipeline, and its AI editing is a black box tied to a subscription. Murmur attacks each of these gaps directly. The built-in notes system supports nested folders, color-coded tags, Markdown editing with live preview, full-text search, and multi-format export. The AI editing pipeline is open and pluggable — users can route through Apple Intelligence, OpenAI, Anthropic, a self-hosted Ollama instance, or write their own provider. There is no telemetry, no subscription, and no vendor lock-in.

### Why Open Source

Murmur is primarily an internal tool built for employees at Unconventional Psychotherapy, but the source code is published under a permissive open-source license. Dictation tools handle some of the most sensitive content a user produces — including therapy-adjacent notes and private communications — and open-sourcing the code allows full auditability of the transcription, editing, and sync pipeline. This transparency is especially important in a psychotherapy context where client confidentiality is paramount. Open-sourcing also allows the broader community to benefit from and contribute to the tool, even though Murmur's primary deployment and target audience is the small internal team at Unconventional Psychotherapy.

### Why macOS 26+

macOS 26 introduces the stable public API surface for Apple SpeechAnalyzer, the on-device continuous speech recognition framework that supersedes the older Speech framework with significantly higher accuracy, lower latency, and first-class support for speaker diarization and punctuation inference. Building on macOS 26+ as the minimum target allows Murmur to use these APIs without shimming or fallback paths, keeping the codebase clean and the transcription quality uniformly high. iOS support follows the same framework availability and provides continuity for users who dictate on mobile.

---

## 2. Product Overview

### 2.1 Problem Statement

Voice dictation on the Mac has existed in some form for two decades, yet it remains a niche workflow tool rather than a primary input modality for most professionals. The reasons are structural:

**Fragmentation of capability.** The built-in macOS dictation feature covers basic transcription but applies no post-processing, has no command mode, does not persist dictations, and cannot be extended. Third-party tools like Wispr Flow solve the quality and flow-through injection problems but introduce a subscription paywall and strip away any notion of persistent output — dictations vanish into whatever app was focused at the time. Users who want both quality dictation and organized output are forced to maintain two separate tools that do not communicate.

**Privacy and trust deficit.** Microphone-always-on products require users to extend significant trust to a vendor whose server-side data handling is unauditable. This is a hard blocker for legal, medical, and enterprise users. Even privacy-conscious casual users are increasingly skeptical of cloud-first audio products following a series of high-profile vendor data incidents.

**No team layer.** Professionals increasingly work in teams, yet dictation tools are invariably single-user. Shared snippet libraries, shared personal dictionaries, and collaborative note access are simply not available in any current dictation product.

**Accessibility gap.** Users with motor disabilities or repetitive strain injuries depend on voice input as an accommodation, not a convenience. For these users, reliability, system-wide coverage, and low-latency feedback are non-negotiable. Current tools treat accessibility as a secondary use case and their pricing models create a recurring financial burden for users who have no alternative.

### 2.2 Goals

**In scope for v1.0:**

- System-wide voice-to-text injection via Accessibility APIs, compatible with any focused text field on macOS
- On-device transcription via Apple SpeechAnalyzer with no mandatory cloud dependency
- AI post-processing pipeline (filler removal, grammar correction, tone adjustment, punctuation normalization) with pluggable providers: Apple Intelligence, OpenAI, Anthropic Claude, and Ollama
- Support for 100+ languages as exposed by the underlying SpeechAnalyzer framework
- Whisper mode (low-volume dictation optimized for open-office environments)
- Personal dictionary with user-defined phonetic mappings and proper noun training
- Snippet library with trigger keywords and variable substitution
- Command mode for application control via voice (scroll, click, select, navigation)
- Code syntax awareness mode (identifier casing, operator verbalization, bracket/brace insertion)
- Built-in notes application: nested folder hierarchy, color-coded tags, Markdown editor with live preview (bold, italic, headings, lists, code blocks, inline links), full-text search with ranking, and export to Markdown, plain text, and PDF
- iCloud + CloudKit sync for notes, snippets, dictionary, and settings across macOS and iOS devices
- iOS companion app with feature parity for dictation and full notes access
- Menu bar helper for low-friction access and visual transcription feedback
- Zero telemetry; no analytics, no crash reporting to external services, no usage data collection

**Non-goals for v1.0:**

- Windows or Linux support
- A web application or browser extension
- Real-time collaborative editing of notes (multiple simultaneous editors)
- Speaker diarization for multi-speaker transcription (targeted for v1.2)
- Native Android application
- A managed cloud sync service operated by the project (users bring their own iCloud account)
- Built-in video or screen recording
- Plugin marketplace or extension sandboxing infrastructure (API is open but no managed distribution)

### 2.3 Success Metrics

Murmur measures success against metrics appropriate for a small internal tool serving 2–10 employees at Unconventional Psychotherapy:

**Employee adoption (first 30 days after rollout):**
- 100% of target employees have installed the app on at least one device (Mac or iPhone)
- 80%+ of employees have completed the onboarding flow (microphone permission, first dictation)
- All employees have iCloud sync active between their devices

**Daily active usage (3-month targets):**
- 80%+ of employees use Murmur at least once per workday
- Average of 2,000+ words dictated per employee per week
- At least 50% of employees use the notes system (not just flow-through dictation)
- Average dictation session length of 30+ seconds (indicating substantive use, not just testing)

**Quality and satisfaction (ongoing):**
- Employee satisfaction score of 4/5 or higher on quarterly internal survey
- Fewer than 2 transcription-accuracy complaints per employee per month
- AI post-processing acceptance rate of 90%+ (users accept the AI edit without manual correction)
- Zero data loss incidents (dictations or notes lost due to sync or app errors)

**Open-source community (secondary, no hard targets):**
- Source code published under a permissive license
- External contributions welcome but not required for the tool to succeed
- Issues and PRs from external contributors are triaged within one week

### 2.4 Competitive Landscape

| Product | Transcription | AI Editing | Notes/Persistence | Privacy | Price |
|---|---|---|---|---|---|
| **Murmur** | On-device (SpeechAnalyzer) + pluggable cloud | Pluggable, open | Full built-in notes app | Open source, zero telemetry | Free (internal tool) |
| **Wispr Flow** | Cloud (proprietary) | Yes, subscription | None | Closed source, cloud audio | $14/mo |
| **macOS Dictation** | On-device | None | None | On-device | Free (built-in) |
| **Superwhisper** | On-device (Whisper) | Limited | None | On-device | $8/mo |
| **Whisper Transcriber** | On-device (Whisper) | None | Basic history | On-device | Free / paid tiers |
| **Otter.ai** | Cloud | Yes | Meeting-focused notes | Cloud, data used for training | $10–20/mo |

---

## 3. User Personas

### Persona 1: Maya Chen — Senior Product Manager

**Demographics:** 34 years old. Senior PM at a 200-person SaaS company in San Francisco. Works remotely three days per week. Uses a MacBook Pro as her primary device and an iPhone for mobile capture.

**Technical fluency:** High consumer-tech fluency, moderate developer fluency. Comfortable with terminal commands, uses Notion heavily, maintains a personal Obsidian vault for thinking work.

**Daily workflow:** Maya's output is almost entirely written: PRDs, one-pagers, Slack messages, JIRA ticket descriptions, stakeholder emails, meeting follow-ups, and weekly status reports. She estimates she types between 3,000 and 5,000 words on an average workday. She has developed mild wrist discomfort over the past year and her physician has recommended reducing keyboard time.

**Pain points:**
- The cognitive shift between thinking and typing disrupts her flow state. She thinks faster than she types and frequently loses the thread of a complex argument while transcribing it.
- She dictates short notes into Apple Voice Memos but they are unsearchable, unorganized, and disconnected from her written output pipeline.
- Wispr Flow trial was promising but the lack of note persistence means every dictation is immediately committed to whatever app is focused — there is no "capture first, decide later" mode.
- Switching between multiple capture tools (voice memo, Notion, Obsidian) fragments her knowledge base.

**Goals:**
- Dictate first drafts of documents at conversational speed, then review and edit in her preferred editor
- Capture fleeting thoughts during walks or between meetings on her iPhone with automatic sync to her Mac
- Maintain a searchable library of raw dictation transcripts alongside polished documents
- Reduce daily keyboard time by at least 40% to address wrist strain

**How Murmur serves Maya:**
Murmur's flow-through injection lets Maya dictate directly into Notion, JIRA, or any web form she has focused. When she wants to capture without committing, she invokes the dedicated notes window and dictates into a new note that is automatically tagged with the current date and optionally pinned to a project folder she has set up for each product area. The Markdown editor lets her add headings and bullet structure with voice commands. On her iPhone, the iOS app captures the same way and syncs via iCloud before she reaches her desk. The AI editing layer handles filler word removal and grammatical cleanup so her first drafts require minimal revision. The personal dictionary is trained on product names, competitor terms, and internal jargon that macOS dictation consistently mangles.

---

### Persona 2: David Okafor — Staff Software Engineer

**Demographics:** 29 years old. Staff engineer at a fintech startup. Works fully remote, primarily on an M-series Mac Studio with a large external display. Uses Neovim as his primary editor, iTerm2, and a heavily customized shell environment.

**Technical fluency:** Expert. Comfortable reading source code, contributing patches, and configuring tooling at a deep level. Active on GitHub. Has submitted issues to several open-source projects.

**Daily workflow:** David's written output includes code, inline code comments, commit messages, PR descriptions, Slack messages, RFC documents, and occasional blog posts. He is an early adopter of keyboard-efficiency tools (has used Vim for six years, maintains his own Hammerspoon config) and approaches voice input from the same optimization mindset: he wants to eliminate low-value keystrokes, not replace the keyboard entirely.

**Pain points:**
- Existing dictation tools have no awareness of code context. Saying "define function fetch user by ID" produces natural-language output rather than idiomatic code syntax. Every dictation into a code environment requires manual correction.
- Command mode in available tools is either absent or covers only a narrow set of system actions. David wants to navigate his editor, trigger Hammerspoon bindings, and execute shell commands by voice.
- He would contribute to a dictation tool if it were open source and written in a language he respects. Current options are closed source or Python scripts with no native UI investment.
- Privacy is non-negotiable. Code he is writing is confidential. He will not route source code fragments through a third-party cloud service.

**Goals:**
- Dictate commit messages, PR descriptions, and Slack messages without leaving keyboard home row
- Use code syntax awareness mode to dictate variable names, function signatures, and simple expressions with correct casing and punctuation
- Contribute to the AI provider plugin system, likely adding support for a self-hosted model endpoint
- Keep all audio and transcription processing on-device with zero cloud egress

**How Murmur serves David:**
The code syntax awareness mode interprets dictation context based on the active application (detected via Accessibility APIs) and applies identifier casing rules (camelCase, snake_case, PascalCase), operator verbalization ("times" → `*`, "double colon" → `::`), and bracket insertion. David configures his preferred casing convention per language in the settings pane. The personal dictionary handles project-specific identifiers. The pluggable AI provider system allows David to point the editing pipeline at a locally running Ollama instance, keeping every token on his machine. Command mode is extensible via a Swift plugin API, and David contributes a Neovim integration within the first month of using the app. The open-source codebase, written in idiomatic Swift with documented architecture, lowers his contribution barrier substantially compared to alternatives.

---

### Persona 3: Sarah Oduya — Freelance Technical Writer (RSI)

**Demographics:** 41 years old. Freelance technical writer and documentation consultant. Has been managing bilateral repetitive strain injury (RSI) for four years. Uses a MacBook Air at home and relies on voice input as her primary means of text production for the majority of the workday. Has tried Dragon Professional, macOS dictation, and Wispr Flow.

**Technical fluency:** Moderate. Comfortable with Mac power-user tools, Markdown, and basic terminal usage. Not a programmer. Evaluates tools primarily on reliability, system-wide coverage, and how much they interrupt her workflow when they fail.

**Daily workflow:** Sarah writes documentation, user guides, API references, and knowledge base articles for technical clients. She works in a mix of Confluence, Notion, VS Code with a Markdown preview, and occasionally Google Docs. Her daily target is 2,000–3,000 words of finished, edited output. On bad pain days she relies on voice input exclusively; on moderate days she supplements keyboard use with voice for longer passages.

**Pain points:**
- Reliability is paramount and current tools fail her in critical ways: Dragon is powerful but its macOS version has stagnated and its UI is from another era; macOS dictation drops words, adds no punctuation, and requires a microphone tap to activate; Wispr Flow is the best experience she has found but the $14/month subscription is a recurring cost she resents for a tool she has no alternative to.
- Accessibility users bear disproportionate financial burden for tools that are marketed as productivity boosters for non-disabled users. A free, high-quality alternative is not just preferable — it is an equity issue.
- The lack of persistent dictation history means that if Wispr Flow injects text incorrectly or the target application crashes, the dictation is gone. She has lost significant work this way.
- Whisper mode is essential in her shared home office. She dictates at low volume to avoid disturbing her partner, and tools that require raised voices produce worse transcriptions or refuse to activate.

**Goals:**
- Maintain full writing productivity on days when keyboard use is medically inadvisable
- Have a persistent safety net: every dictation captured in searchable history regardless of what happened to the target application
- Use whisper mode reliably throughout the workday without configuring microphone gain per session
- Access the tool at no recurring cost, permanently

**How Murmur serves Sarah:**
Murmur's always-on menu bar helper activates on a customizable hotkey with no microphone tap required. Whisper mode is a persistent toggle, not a session setting, and the app automatically calibrates input gain normalization when it is active. Every dictation — whether injected into a third-party app or captured to a note — is written to the notes database immediately, providing a complete recovery log. Sarah uses the notes inbox as her default capture target on difficult days, dictating entire document drafts into the notes app before copying finished sections into Confluence. The full-text search lets her recover any phrase she has ever dictated. The export pipeline (Markdown, DOCX) fits her existing delivery workflow. The zero-cost model removes the subscription anxiety that has made her relationship with Wispr Flow feel precarious.

---

### Persona 4: James Whitfield — Engineering Director

**Demographics:** 46 years old. Engineering Director at a 600-person enterprise software company. Manages four teams totaling 28 engineers. Splits time between a Mac at his standing desk and an iPad Pro in meetings. Heavy calendar user; spends 60–70% of his workday in meetings or 1:1s.

**Technical fluency:** Formerly a software engineer, now primarily a manager. Can read code fluently, contributes occasional scripts, but has not written production code in four years. Evaluates tools from a team-adoption and information-architecture perspective as much as a personal-productivity perspective.

**Daily workflow:** James produces a high volume of low-to-medium-complexity text: meeting follow-up emails, performance review drafts, Slack thread summaries, OKR documentation, hiring rubrics, escalation writeups, and strategic memos. He processes approximately 150 Slack messages and 80 emails per day and sends roughly 40 replies. His writing is frequent, varied, and time-pressured. He has experimented with voice input twice before and abandoned it because the tooling was not reliable enough to trust in front of his team.

**Pain points:**
- He has a recurring need to distribute boilerplate text — standard meeting agenda formats, performance review framework language, escalation templates — that he currently maintains in a messy Notion database. Snippet libraries in dictation tools are scoped to personal use and have no sharing mechanism.
- The team he manages includes two engineers with documented RSI accommodations. He is responsible for ensuring their toolchain meets their needs and resents that the best available accessibility tools require individual subscriptions that must be expensed individually.
- He is skeptical of cloud audio products for enterprise use. His company's security team would not approve routing meeting follow-up content through an unaudited third-party cloud service.
- He wants to be able to dictate from his iPad in back-to-back meetings without a context switch to a second tool. The current market offers no coherent cross-device dictation and notes experience.

**Goals:**
- Reduce time spent on routine written communication by using voice for first drafts and standard replies
- Maintain a shared snippet library with his EA and chief of staff for consistent team communication templates
- Ensure team members with accessibility needs have access to the same high-quality tool without per-seat cost
- Work from iPad in meetings with the same dictation and note-access experience as his Mac

**How Murmur serves James:**
The CloudKit-backed snippet library syncs across all of James's devices and, by sharing iCloud family or organizational access, can be used collaboratively with his EA and chief of staff — each maintaining a shared folder of team templates alongside their personal snippets. The pluggable AI provider means his company's security team can approve the specific model endpoint in use (on-device Apple Intelligence, a self-hosted instance, or their enterprise OpenAI agreement) rather than evaluating an opaque third-party cloud service. The iOS app provides full notes access and dictation on his iPad in meetings, with seamless handoff to his Mac. He can provision the app for team members with accessibility accommodations at zero marginal cost and without an approval process, removing a recurring administrative friction. The notes system becomes his lightweight decision log and meeting follow-up archive, reducing his dependence on Notion for low-stakes capture.

---

### Persona 5: Dr. Amara Obi — Psychotherapist (Unconventional Psychotherapy)

**Demographics:** 38 years old. Licensed clinical psychologist at Unconventional Psychotherapy. Sees 6–8 clients per day. Uses a MacBook Air in her office and an iPhone between sessions. Works primarily with individual therapy clients.

**Technical fluency:** Moderate consumer-tech fluency. Uses Apple Notes, a practice management EHR (Electronic Health Record), and email daily. Not a programmer; evaluates tools on reliability and simplicity.

**Daily workflow:** After each therapy session, Amara writes session notes within her practice management system. She also drafts client communications (appointment confirmations, treatment summaries for referring physicians, insurance documentation). Her daily written output is 1,500–2,500 words, most of it produced in the 10–15 minute gaps between sessions. She writes standing at a counter or sitting in a lounge chair — rarely at a desk.

**Pain points:**
- Writing session notes at a keyboard between sessions is time-consuming and physically constraining. She would prefer to dictate notes while stretching or walking in her office.
- Client names, medication names, and clinical terminology (DSM-5 diagnoses, therapeutic modalities) are consistently misrecognized by macOS dictation.
- She is deeply concerned about client confidentiality. Any tool that sends audio or text to a cloud service is unacceptable for clinical content without explicit, auditable guarantees.
- Her EHR's built-in note templates are rigid. She wants to capture notes freely and then paste completed sections into the appropriate EHR fields.

**Goals:**
- Dictate session notes hands-free between appointments, with clinical terminology accurately transcribed
- Keep all clinical content on-device — no cloud AI processing for therapy-related text
- Build a personal dictionary of client names, medications, and clinical terms
- Export notes in a format compatible with her EHR's paste workflow

**How Murmur serves Amara:**
Clinical Mode (enabled by default when the practice management EHR is the active app) disables all cloud AI providers and routes processing exclusively through Apple Intelligence on-device. Her personal dictionary contains client names, medications (SSRIs, SNRIs, benzodiazepines), DSM-5 diagnostic codes, and therapeutic modality names (CBT, DBT, EMDR, IFS). Session notes are captured as notes in a "Client Sessions" folder with date-based titles. She dictates standing in her office using the iPhone app between sessions when her MacBook is not within reach, and notes sync to her Mac via iCloud before she returns to her desk. The Markdown export copies cleanly into her EHR's text fields.

---

### Persona 6: Marcus Rivera — Practice Administrator (Unconventional Psychotherapy)

**Demographics:** 31 years old. Office manager and practice administrator at Unconventional Psychotherapy. Handles scheduling, insurance billing, client intake, and internal documentation. Uses a Mac mini at his desk and an iPhone for on-the-go communication.

**Technical fluency:** High consumer-tech fluency, comfortable with spreadsheets, practice management software, and basic automation. Not a developer but a power user of existing tools.

**Daily workflow:** Marcus produces a high volume of routine administrative text: appointment confirmation messages, insurance pre-authorization letters, client intake summaries, internal policy memos, and vendor communications. He estimates typing 2,000–3,000 words per day across email, the EHR, and internal documents. Much of this text follows standard templates with client-specific details filled in.

**Pain points:**
- Typing repetitive template text (insurance letters, intake summaries) is tedious and error-prone. He frequently copies from previous letters and misses fields that need updating.
- Client names and insurance provider names are often misspelled by dictation tools.
- He needs to produce professional, well-formatted documents quickly — first drafts that require minimal editing.

**Goals:**
- Use snippets for common templates (insurance authorization letters, appointment confirmations) with variable substitution for client-specific fields
- Dictate administrative communications at conversational speed with professional tone auto-applied
- Maintain accurate dictation of insurance company names, procedure codes, and client details via personal dictionary
- Send formatted text directly into email and the EHR without intermediate copy-paste steps

**How Murmur serves Marcus:**
Marcus maintains a snippet library with templates for his most common documents: `ins-auth` expands to an insurance pre-authorization letter template with `{clientName}`, `{dateOfService}`, `{diagnosisCode}`, and `{providerName}` variables. The "Business Casual" tone profile is applied by default for his email app, producing polished first drafts from casual dictation. His personal dictionary includes all insurance company names, procedure codes (CPT codes), and client names the practice serves. Flow-through injection puts dictated text directly into his email compose window or EHR text field, while the automatic note safety net preserves a copy of every dictation in his "Admin" folder for reference.

# Section 4: Feature Specifications

---

## 4.1 Core Dictation Engine

### 4.1.1 Activation Modes

Murmur supports three mutually exclusive activation modes, configurable per-user in Settings > Dictation > Activation. The active mode persists across app restarts.

**Hold-to-Dictate (Default)**

The primary activation mode mirrors the Fn key behavior popularized by Wispr Flow. When the user presses and holds the Fn key (configurable to any key or modifier combination), dictation begins immediately. Releasing the key ends the session and triggers the AI editing pipeline before injecting text.

- Activation latency: ≤ 80 ms from key-down event to microphone open
- Deactivation: key-up event ends recording; a minimum hold duration of 300 ms is required to prevent accidental triggers
- Visual indicator: the menu bar icon animates to a pulsing waveform during active recording
- Configurable trigger keys: Fn (default), Right Option, Right Command, Caps Lock, or a custom double-tap sequence on any modifier
- Fn key conflict resolution: if the system or another app captures Fn, Murmur falls back to the user-configured secondary key; a conflict warning appears in Settings
- Key repeat suppression: key-repeat events during hold do not re-trigger the engine

**Toggle Mode**

A single press starts dictation; a second press ends it. Suitable for long-form dictation where holding a key is impractical.

- First press: opens session, shows persistent recording HUD
- Second press: ends session, triggers pipeline
- Safety timeout: configurable maximum session duration (default 5 minutes) with a 30-second warning; the user may extend in 5-minute increments via the HUD
- Background safety: if the app loses focus during a toggle session, dictation continues but a floating HUD remains visible on screen

**Always-On Mode**

Continuous voice activity detection (VAD) with push-to-transcribe behavior. The engine listens at all times using low-power VAD and begins transcribing when speech is detected above the configured threshold.

- VAD threshold: adjustable sensitivity slider (Low / Medium / High / Custom dB value)
- Pause detection: silence of ≥ 1.5 seconds (configurable 0.5–5.0 s) ends the current utterance and triggers the pipeline
- Privacy indicator: a persistent, non-dismissible orange dot appears in the menu bar whenever the microphone is open in always-on mode, per Apple HIG guidelines
- Opt-in only: Always-On requires explicit user consent with a privacy disclosure on first enable; consent is re-requested after OS updates
- Power management: always-on mode is automatically suspended when the device is on battery below 20% unless the user explicitly overrides

### 4.1.2 Apple SpeechAnalyzer / SpeechTranscriber Integration

Murmur uses Apple's `SpeechAnalyzer` framework as the on-device transcription foundation, targeting the stable API surface introduced in macOS 26 / iOS 26. No compatibility shim for older OS versions is maintained — macOS 26+ and iOS 26+ are the minimum supported versions.

**SpeechAnalyzer Configuration**

- `SpeechAnalyzer` is initialized at app launch and kept warm; cold-start initialization is performed on a background actor to avoid blocking the main thread
- A `SpeechTranscriptionSession` is created per dictation session; sessions are not reused across separate activations
- `AnalysisOptions` configured per session: `.transcribe`, `.punctuate`, `.languageIdentification`, `.disfluencyAnnotation` (for filler word metadata), `.alternatives(count: 3)` for correction support
- Audio format: 16 kHz, 16-bit PCM mono, fed via `AVAudioEngine` tap at 100 ms buffer intervals
- Partial results streamed via `AsyncStream<SpeechTranscription>` and rendered in the real-time preview UI
- Final result consumed after session `.finalize()` call; the final transcription is passed to the AI editing pipeline
- On-device model selection: Murmur requests the highest-quality on-device model via `SpeechAnalyzerConfiguration.modelQuality = .high`; if unavailable, gracefully falls back to `.default`
- Model download: if the required locale model is not present, Murmur prompts the user to download it; download is performed in the background with progress indication

**Audio Session Management**

- macOS: `AVAudioEngine` with input node tap; exclusive audio session not required
- iOS: `AVAudioSession.Category.record` with `.allowBluetooth` and `.defaultToSpeaker` options; session is activated on dictation start and deactivated on end
- Audio interruption handling: phone calls, Siri, and other interruptions suspend the session gracefully with partial text preserved; resumption is offered to the user
- Audio route change handling: microphone disconnection mid-session pauses recording, displays an alert, and preserves partial transcription

### 4.1.3 Whisper Mode

Whisper mode enables accurate transcription of very soft speech, designed for open offices, libraries, or situations where the user does not want to speak at normal volume.

- Activation: toggled via a Whisper Mode button in the HUD, a keyboard shortcut (configurable, default ⌃⌥W), or a voice command ("enable whisper mode")
- Input gain boost: applies a +12 dB software gain to the audio input before passing to the speech engine; the gain value is configurable (0–20 dB)
- Noise gate: a tighter noise gate (configurable threshold, default –45 dBFS) suppresses ambient noise that becomes more prominent at high gain
- UI indication: the HUD and menu bar icon display a distinct whisper mode indicator (microphone icon with a small "shh" symbol)
- Accuracy note: a one-time informational tooltip informs users that whisper mode may have slightly lower accuracy than normal-volume speech
- Per-session toggle: whisper mode state resets to the user's default setting at the start of each new session unless "sticky whisper mode" is enabled in Settings

### 4.1.4 Language Support

**Supported Language Count**

Murmur targets ≥ 110 languages at launch, aligned with the languages available through Apple's Speech framework. The exact set is determined at runtime by querying `SpeechAnalyzer.supportedLocales` and `SFSpeechRecognizer.supportedLocales`.

**Language Selection**

- Default: "Auto-detect" (see 4.1.5)
- Manual selection: a searchable language picker in Settings > Dictation > Language
- Per-session override: the language can be changed from the HUD without opening Settings
- Recent languages: the 5 most recently used languages are pinned at the top of the picker
- Locale variants: where Apple provides multiple regional variants (e.g., `en-US`, `en-GB`, `en-AU`), all variants are exposed and independently selectable

**Model Availability**

- The language picker displays a download badge next to languages whose on-device models are not yet downloaded
- Background download is triggered when a language is selected; a progress indicator is shown in the picker
- Downloaded model sizes are displayed; the user can delete unused models from Settings > Storage

### 4.1.5 Mixed-Language Dictation

Mixed-language dictation allows users to speak two or more languages within a single utterance without switching modes. This is a first-class feature for bilingual professionals.

**Implementation**

- `SpeechAnalyzer` language identification runs per-segment on the audio stream, identifying the most likely locale for each 500 ms audio window
- A configurable "language roster" of 2–5 languages is set by the user; identification is constrained to this roster for improved accuracy (unconstrained identification is an opt-in setting)
- Language transitions within a sentence are handled at the token level; no artificial pause is required between language switches

**User Configuration**

- Settings > Dictation > Mixed Language: toggle to enable, plus a roster picker
- The roster picker enforces a minimum of 2 and maximum of 5 languages
- "Smart Roster": an optional mode that automatically adds a language to the roster if it is detected with high confidence (≥ 0.85) three or more times in a single session

**Output Handling**

- The final transcription is a single string; language boundaries are not marked in the injected text
- The note metadata records all detected languages for the session
- The AI editing backend receives a `detectedLanguages: [Locale]` field in the prompt context so it can apply appropriate grammar rules per segment

### 4.1.6 Real-Time Transcription Feedback

**Waveform Visualizer**

- An audio waveform is displayed in the floating HUD during active recording
- Rendered using Metal-backed `Canvas` in SwiftUI for smooth 60 fps animation
- Waveform style: configurable between bar graph, line wave, and circular modes
- Color: adapts to the user's accent color preference; turns amber when the microphone gain approaches clipping

**Live Text Preview**

- Partial transcription results are displayed in the HUD in real time as the speech engine produces interim results
- Text streams in word-by-word; confirmed words are rendered in full opacity, in-progress words in 50% opacity
- Preview area: scrollable, up to 5 lines visible; older text scrolls up automatically
- The preview does not inject text into the target app until the session ends and the pipeline completes

**Confidence Visualization**

- Low-confidence words (below a configurable threshold, default 0.65) are underlined in amber in the preview
- After injection, the same low-confidence words are briefly highlighted in the target text field (where accessibility permits) for 2 seconds

**Session Timer**

- Elapsed recording time is displayed in the HUD (MM:SS format)
- A configurable warning color change occurs at 80% of the maximum session duration

### 4.1.7 Microphone Selection and Gain Control

- **Default microphone**: follows the system default input device; changes to the system default are reflected immediately between sessions (not mid-session)
- **Override**: Settings > Audio > Input Device; a dropdown lists all available input devices by name with device type icon (built-in, USB, Bluetooth, virtual)
- **Per-device gain**: a software pre-gain slider per device (–10 dB to +20 dB); distinct from the whisper mode gain boost
- **Level meter**: a real-time input level meter is displayed in Settings and in the HUD; a clipping indicator flashes when the input signal exceeds –3 dBFS
- **Bluetooth latency warning**: if a Bluetooth HFP device is selected, a latency warning is displayed noting potential impact on recognition accuracy
- **AirPods**: AirPods and AirPods Pro are explicitly supported; Transparency Mode and Active Noise Cancellation state do not affect dictation behavior

### 4.1.8 Dictation Session Management

**Session Lifecycle**

Each dictation session follows a strict state machine: `Idle → Activating → Recording → Processing → Injecting → Idle`. Errors at any stage transition to an `Error` state with a specific error code.

**Partial Session Recovery**

- If the app crashes during a Recording state, the audio buffer is flushed to a temporary file; on next launch, the user is offered the option to complete transcription of the recovered audio
- Partial transcription text (from interim results) is stored in memory during recording and saved to a recovery file every 10 seconds

**Session History**

- The last 50 sessions are stored in a session log accessible from the menu bar (History submenu)
- Each session log entry records: timestamp, duration, word count, source app, language(s), and the final edited text
- Sessions can be promoted to full notes with one click from the history log
- Session log entries are cleared after 30 days by default (configurable)

**Concurrent Session Prevention**

- Only one dictation session may be active at a time
- Attempting to start a session while one is active produces a gentle audio chime and an inline HUD message
- On iOS, receiving a phone call immediately suspends the active session

---

## 4.2 AI Auto-Editing (Pluggable Backend)

### 4.2.1 Pipeline Architecture

The AI editing pipeline is an asynchronous, multi-stage process that transforms raw transcription into polished text. The pipeline is invoked after every dictation session (unless disabled) and before text injection.

**Pipeline Stages (in order)**

1. **Pre-processing**: tokenize raw transcription, detect backtrack markers, segment into logical clauses
2. **Backtrack resolution**: remove backtracked segments (see 4.2.3)
3. **Filler word removal**: strip disfluencies (see 4.2.2)
4. **Grammar & punctuation correction**: apply auto-punctuation and grammar fixes
5. **Style adaptation**: apply per-app tone profile (see 4.2.4)
6. **Command execution**: if command mode phrases are detected, execute them (see 4.2.5)
7. **Post-processing**: final formatting, normalize whitespace, apply snippet expansions

Each stage is individually toggleable in Settings > AI Editing. Disabled stages are bypassed, not removed from the pipeline.

**Latency Budget**

- Total pipeline latency target: ≤ 1.5 seconds for sessions up to 60 seconds of speech
- Local/Apple Intelligence provider target: ≤ 400 ms
- Cloud provider target: ≤ 1.2 seconds (network-dependent)
- A progress indicator appears in the HUD during pipeline processing; the user may cancel at any stage to inject the raw transcription immediately

### 4.2.2 Filler Word Removal

**Filler Word Detection**

The filler word list is applied in the pre-processing stage before the AI backend call to reduce token cost and latency. Patterns matched by regex before AI processing:

- Standalone fillers: "um", "uh", "er", "ah", "hmm", "mm"
- Phrase fillers: "you know", "I mean", "like" (as a discourse marker), "basically", "literally" (non-literal use), "right", "so" (as a sentence-opening filler), "anyway"
- Repeated words: consecutive identical word tokens (e.g., "the the") are collapsed to one
- False starts without backtrack marker: detected heuristically as a word or phrase followed immediately by rephrasing

**Filler Word Configuration**

- Default filler list is editable: users may add or remove words/phrases in Settings > AI Editing > Filler Words
- Language-specific filler lists are maintained separately; adding to the list for one language does not affect others
- "Aggressive" mode: an optional higher-sensitivity mode that also removes hesitation phrases like "let me think", "how do I put this"
- Per-app override: filler removal can be disabled for specific apps (e.g., a transcription app where the user wants verbatim output)

**AI-Assisted Filler Detection**

- For fillers that are context-dependent (e.g., "like" can be a legitimate word or a filler), the AI backend makes the final determination
- The AI provider receives a `fillerAnnotations: [Range]` array from the pre-processing stage as a hint, which it may override

### 4.2.3 Backtrack Correction

Backtrack correction detects when the user verbally signals they want to revise what they just said and automatically removes the unwanted segment.

**Trigger Phrases (default, user-configurable)**

- "no wait" / "no wait wait"
- "actually" (at the start of a clause following speech)
- "I mean" (when used as a correction signal, not an explanation)
- "scratch that"
- "delete that"
- "never mind"
- "let me rephrase"
- "correction"
- "I meant to say"

**Resolution Logic**

- The pre-processor identifies a backtrack trigger and marks the preceding clause boundary as the deletion point
- "Clause" is defined as text since the last sentence-ending punctuation, comma, or 2+ second pause
- If the trigger phrase is itself followed by corrected content ("no wait, I meant Tuesday"), the corrected content replaces the deleted segment
- If the trigger phrase is terminal (nothing follows it), the preceding clause is deleted entirely
- Ambiguous cases (where the deletion scope is unclear) are passed to the AI backend with explicit backtrack annotations for resolution

**Visual Feedback**

- In the HUD preview, struck-through text briefly shows the deleted segment before it disappears, giving the user visual confirmation of what was removed (configurable, default on, disappears after 1.5 seconds)

### 4.2.4 Auto-Punctuation and Grammar Correction

**Punctuation**

- Apple's `SpeechAnalyzer` with the `.punctuate` analysis option provides baseline punctuation
- The AI backend performs a secondary punctuation pass, particularly for: list detection, dialogue quotation marks, em dashes for asides, ellipsis normalization, Oxford comma preference (configurable), and serial comma style
- Sentence boundary detection: the AI corrects cases where the speech engine incorrectly merges or splits sentences

**Grammar Correction**

- Subject-verb agreement
- Article usage (a/an, the)
- Pronoun case
- Tense consistency within a passage
- Commonly confused words (their/there/they're, its/it's, etc.)
- Grammar correction is non-destructive: the AI is instructed to prefer minimal edits that preserve the user's voice

**Capitalization**

- Sentence-initial capitalization
- Proper noun capitalization (informed by the personal dictionary; see 4.3.1)
- All-caps detection and normalization (shouted speech that should be normal case)
- Acronym capitalization (configurable: always uppercase, match dictionary, or pass-through)

### 4.2.5 Tone and Style Adaptation

**App Context Detection**

The active application at the time of dictation start is captured and mapped to a tone profile. The mapping is maintained in Settings > App Profiles (see 4.3.5).

**Built-In Tone Profiles**

| Profile | Description | Example Adjustment |
|---|---|---|
| Formal | Professional emails, documents | Full sentences, formal vocabulary, no contractions |
| Business Casual | Slack, Teams, internal comms | Contractions allowed, friendly but clear |
| Casual | iMessage, WhatsApp, social | Informal, contractions, short sentences |
| Technical | IDEs, terminals, documentation | Precise terminology, code-adjacent formatting |
| Creative | Notes, writing apps | Preserves idiosyncratic style, minimal correction |
| Verbatim | Transcription apps | No edits except explicit fillers; preserves all punctuation from speech |

**Style Application**

- Tone profiles are applied via a system prompt segment injected into the AI provider call
- The AI is explicitly instructed not to change the meaning or add information not present in the raw transcription
- Tone intensity: a slider (Subtle / Moderate / Strong) controls how aggressively the AI applies the profile; "Subtle" only fixes clear errors, "Strong" fully reformats

### 4.2.6 Command Mode

Command mode allows users to issue meta-instructions to the AI during or after dictation, causing it to transform the transcribed text rather than inject it verbatim.

**Phase 2 Scope: Text Editing Commands Only**

Phase 2 delivers a focused set of text editing commands. App navigation commands (scroll, click, select UI elements, navigate menus) are deferred to Phase 4+ because they require a fundamentally different interaction model (continuous voice control vs. post-dictation transformation).

**Phase 2 Command Vocabulary**

| Command | Action | Example |
|---|---|---|
| "new line" / "new paragraph" | Inserts line break(s) | "...end of sentence new line next point is..." |
| "delete that" / "scratch that" | Deletes the preceding clause/sentence | "...the meeting is on Tuesday delete that Wednesday" |
| "undo" / "undo that" | Reverts the last AI edit or deletion | "delete that... undo" |
| "select all" | Selects all text in the current dictation | Used before a transformation command |
| "capitalize that" / "all caps" / "lowercase" | Case transformation on preceding word/phrase | "...meeting with john capitalize that" |
| "make this formal" / "make this casual" | One-time tone transformation | Spoken at end of dictation |
| "bullet point this" / "make this a numbered list" | Reformats as list | Spoken at end of dictation |
| "fix the grammar only" | Bypasses tone adaptation | Spoken at end of dictation |
| "translate to [language]" | Translates the full transcription | "translate to French" |
| "summarize this" | Produces a summary | Spoken at end of dictation |

**Command Detection**

- Commands are detected in a pre-processing pass using a curated regex/keyword list; matched candidates are sent to the AI with a `potentialCommands: [String]` annotation
- The AI makes the final determination of whether a phrase is a command or content
- Ambiguous cases: if command confidence is below 0.75, the HUD shows an inline disambiguation prompt ("Did you mean to apply the command 'make this more concise'?") with a 3-second auto-dismiss defaulting to "yes"

**Command History**

- The last 20 commands issued are stored in a command history accessible from Settings > AI Editing > Command History
- Frequently used commands (≥ 3 uses in 7 days) are promoted to a Quick Commands list shown in the HUD

**Custom Commands**

- Users may define custom commands in Settings > AI Editing > Custom Commands
- Each custom command has: trigger phrase(s), a natural-language instruction sent to the AI, and an optional keyboard shortcut
- Example: trigger "executive summary" → instruction "Rewrite the following as a 3-bullet executive summary suitable for C-suite communication"

**Phase 4+: App Navigation Commands**

Advanced voice commands for app navigation (scroll, click, select, navigate) are planned for Phase 4. These require continuous voice activity monitoring and an accessibility-layer integration that goes beyond post-dictation text transformation.

### 4.2.7 AI Backend Providers

**Provider Abstraction Layer**

All AI providers implement the `AIEditingProvider` protocol:

```swift
protocol AIEditingProvider {
    var id: ProviderID { get }
    var displayName: String { get }
    var capabilities: Set<ProviderCapability> { get }
    func edit(_ request: EditingRequest) async throws -> EditingResult
    func isAvailable() async -> Bool
}
```

`ProviderCapability` includes: `.fillerRemoval`, `.grammarCorrection`, `.toneAdaptation`, `.commandMode`, `.translation`, `.summarization`.

**OpenAI Provider**

- Models: GPT-4o (default), GPT-4o-mini (low-latency option), GPT-4 Turbo; model is user-selectable
- API endpoint: configurable (default `api.openai.com`; custom base URL supported for proxies/Azure OpenAI)
- API key storage: macOS Keychain, never written to disk in plaintext
- Token budget: configurable max tokens per request (default 2048 output); the request includes the raw transcription plus a compact system prompt
- Streaming: uses streaming API for faster time-to-first-token in the HUD preview

**Anthropic Claude Provider**

- Models: Claude 3.5 Sonnet (default), Claude 3 Haiku (low-latency), Claude 3 Opus (high-quality); user-selectable
- API key stored in macOS Keychain
- Uses Anthropic Messages API; system prompt injected as the `system` field
- Extended thinking: optionally enabled for complex command mode operations (disabled by default due to latency)

**Ollama Provider (Local)**

- Connects to a local Ollama instance at a configurable endpoint (default `http://localhost:11434`)
- Model: any model pulled into the local Ollama instance; user selects from a dynamically fetched list of available models
- No API key required
- Privacy guarantee: all processing stays on-device; a "fully local" badge is displayed in the AI status indicator
- Latency: highly variable; a timeout of 10 seconds is enforced (configurable up to 60 s) before fallback triggers
- Model capability detection: the provider queries the model's metadata; if the model lacks sufficient context window (< 4096 tokens), a warning is displayed

**Apple Intelligence Provider**

- Uses the Writing Tools APIs introduced in macOS 15 / iOS 18 where available
- On macOS 26 / iOS 26, integrates with the Foundation Models framework for on-device LLM inference
- Capabilities: grammar correction, tone adaptation, summarization; command mode support is limited to built-in Writing Tools actions
- No internet connection required; no API key required
- Automatically selected as the default provider if no cloud API keys are configured
- Availability check: `WritingToolsCoordinator.isAvailable` / `FoundationModel.isAvailable`; graceful degradation if unavailable (e.g., older device without Apple Intelligence)

### 4.2.8 Provider Configuration UI

Settings > AI Editing > Providers presents a provider management interface:

- A list of all configured providers in priority order (drag to reorder)
- Each provider card shows: name, status (Active / Configured / Not Configured / Unavailable), model selection dropdown, and a "Test Connection" button
- "Add Provider": a sheet to configure a new provider instance (same provider type may be added multiple times with different configurations, e.g., two OpenAI accounts)
- API keys: entry fields with show/hide toggle; "Verify Key" button makes a minimal test API call and reports success/failure with error details
- Usage display: tokens used this month (fetched from provider usage API where available)
- Cost estimate: estimated monthly cost based on current usage rate (OpenAI and Claude only)

### 4.2.9 Fallback Chain

- The fallback chain is the ordered list of providers in Settings > AI Editing > Providers
- When the primary provider fails (network error, API error, timeout, rate limit), Murmur automatically retries with the next provider in the chain
- Fallback is transparent to the user by default; an optional notification setting can alert the user when a fallback occurs
- Fallback attempts: each provider in the chain is tried once; if all fail, the raw (pre-AI) transcription is injected with a non-intrusive banner notification ("AI editing unavailable — raw transcription injected")
- Circuit breaker: a provider that fails 5 times in 10 minutes is temporarily removed from the active chain for 5 minutes to avoid repeated latency penalties

### 4.2.10 Raw vs. Edited Output Toggle

- A "Raw / Edited" toggle appears in the HUD after pipeline completion and before injection
- Default: shows the edited output
- Toggling to Raw shows the verbatim transcription (post-backtrack resolution but pre-AI editing)
- The user may edit either version in the HUD preview pane before confirming injection
- A diff view (optional, toggleable with ⌘D in the HUD) highlights changes the AI made, using green for additions and red for deletions
- The choice is remembered per-app profile; some users may prefer raw output in certain apps

---

## 4.3 Personalization

### 4.3.1 Personal Dictionary

**Auto-Learning**

- When the user manually corrects a transcription (either in the HUD preview or by editing injected text and triggering a correction feedback gesture), the corrected word is added to the personal dictionary
- Correction feedback gesture on macOS: select the incorrect word → right-click → "Add to Personal Dictionary" context menu item
- iOS: select incorrect word → Share Sheet → "Add to Murmur Dictionary"
- Minimum frequency threshold: a word must be corrected 2+ times before automatic addition to reduce false learning from typos

**Manual Dictionary Management**

- Settings > Personalization > Dictionary: a searchable list of all dictionary entries
- Each entry contains: the word/phrase as spoken, the intended transcription, phonetic hint (optional), language, date added, and usage count
- Bulk import: import a `.txt` or `.csv` file of word-transcription pairs
- Bulk export: export the personal dictionary as `.csv` or `.json`
- Sync: the personal dictionary syncs via iCloud CloudKit; entries are merged (union) across devices with conflict resolution by recency

**Entry Types**

- **Simple substitution**: spoken form → written form (e.g., "mick roh soft" → "Microsoft")
- **Proper noun**: name with correct capitalization (e.g., "mckayla" → "McKayla")
- **Acronym**: spoken form → acronym (e.g., "kay p i" → "KPI", always uppercase)
- **Phrase**: multi-word spoken form → multi-word written form

### 4.3.2 Phonetic Mappings

Phonetic mappings address the specific challenge of proper nouns, brand names, and technical terms that speech engines consistently mishear.

- Each mapping stores: the exact phonetic string the speech engine produces, the correct output string, and an optional note explaining the mapping
- Example: speech engine produces "Nia Varones" → user maps to "Niall Farren"
- Mappings are applied as a final substitution pass in pre-processing, before the AI pipeline, using exact string matching (case-insensitive)
- Mapping scope: Global, or scoped to specific languages or app profiles
- The mapping editor includes a "Test" input field: type what the speech engine would produce, and see the mapped output in real time

### 4.3.3 Snippet Library

Snippets allow users to expand short trigger phrases into longer text templates, potentially with dynamic variables.

**Snippet Structure**

Each snippet contains:
- `name`: human-readable name
- `trigger`: one or more spoken trigger phrases (e.g., "my email", "sig", "insert signature")
- `expansion`: the output text, which may contain variables
- `language`: the language(s) in which the trigger is active
- `appScope`: global or restricted to specific apps
- `caseSensitive`: boolean

**Variables**

Snippets support dynamic variables enclosed in `{{double braces}}`:

| Variable | Output |
|---|---|
| `{{date}}` | Current date (locale-formatted) |
| `{{time}}` | Current time |
| `{{datetime}}` | Date and time |
| `{{day}}` | Day of week |
| `{{clipboard}}` | Current clipboard contents |
| `{{cursor}}` | Cursor position marker (text before/after) |
| `{{input: "prompt"}}` | Prompts user for input in a mini popover |
| `{{app}}` | Name of the target application |

**Snippet Management UI**

- Settings > Personalization > Snippets: a table view listing all snippets
- Inline editing directly in the table; a full-screen editor sheet for complex snippets
- Import/export: `.json` format containing the full snippet library
- Snippet conflicts: if two snippets share a trigger phrase, both are listed with a conflict badge; the user must resolve by removing or renaming one

**Snippet Triggering**

- During post-processing, the final text is scanned for trigger phrases
- Trigger matching is performed on word boundaries; partial word matches do not trigger
- When a trigger is found, an expansion confirmation briefly appears in the HUD (dismiss with Escape to inject the trigger phrase literally)

### 4.3.4 Style and Tone Presets

Beyond the built-in profiles in 4.2.5, users may create fully custom style presets:

- Settings > Personalization > Styles: a list of style presets (built-in + user-created)
- Each preset contains: name, base tone (inherits from a built-in profile), custom system prompt segment (optional, plain text, 500 character limit), and formatting preferences (oxford comma, number format, date format, etc.)
- Active preset: selected globally, or overridden per app profile
- Sharing: presets may be exported as `.json` and shared with other users (manual import; no automatic cloud sharing in v1)

### 4.3.5 Per-App Behavior Profiles

App profiles allow entirely different behavior for different applications, accommodating the reality that a user's needs in Xcode are very different from their needs in Mail.

**Profile Attributes**

Each app profile configures:
- Target app (selected from a picker showing installed apps)
- Active tone preset
- AI editing: on/off
- Filler removal: on/off
- Backtrack correction: on/off
- Default injection method: accessibility API / clipboard / ask each time
- Code mode: on/off (see 4.6)
- Snippet scope: global snippets + app-specific snippets
- Post-injection cursor behavior: end of insertion / beginning of insertion / no change

**Profile Discovery**

- When a new app is first targeted for dictation, Murmur checks whether a profile exists for it
- If no profile exists, the global defaults are used
- After the session, a prompt appears: "You dictated into [App Name] for the first time. Would you like to create a custom profile for it?" with a "Create Profile" button
- Profiles are listed in Settings > App Profiles, sorted by most recently used

### 4.3.6 Voice Training and Calibration

**Initial Calibration**

- On first launch, a guided calibration wizard prompts the user to read 15 short sentences aloud
- The calibration data is used to tune gain levels, VAD thresholds, and (where supported by the Speech framework) speaker adaptation
- Calibration takes approximately 2–3 minutes and can be skipped and performed later from Settings > Audio > Calibrate

**Ongoing Adaptation**

- The speech engine passively improves over sessions via Apple's on-device model adaptation (where available in the framework)
- Users may trigger a re-calibration at any time from Settings > Audio > Recalibrate
- Calibration data is stored locally only and never transmitted to any server; it is included in the app's iCloud backup if the user opts in

**Noise Environment Profiles**

- Users may save named noise environment profiles (e.g., "Office", "Home", "Café") that store microphone gain, VAD threshold, and noise gate settings
- Active profile can be switched from the HUD or menu bar

---

## 4.4 Notes and Organization System

The Notes and Organization system is a key differentiator for Murmur. While Wispr Flow focuses solely on dictation, Murmur provides a full-featured, dictation-native note-taking environment that automatically captures and organizes everything the user dictates.

### 4.4.1 Folder Hierarchy

**Structure**

- The folder hierarchy is a tree of unlimited depth; there is no enforced limit on nesting levels
- The root level contains folders and ungrouped notes ("All Notes" is a virtual root view, not a real folder)
- Folders may contain: subfolders and notes (no other content types)
- Folder attributes: name (unique among siblings), color (16 predefined colors + custom hex), icon (SF Symbol selection from 200 curated icons), created date, modified date

**Folder Operations**

- Create: "New Folder" button in the sidebar, or right-click context menu on an existing folder
- Rename: double-click on folder name in sidebar (inline edit); confirmation on Return, cancel on Escape
- Delete: moves all contents to Trash (see 4.4.13); folder cannot be deleted while containing non-trashed notes unless the user confirms bulk trash
- Move: drag-and-drop in the sidebar; also accessible via right-click > Move To; keyboard shortcut ⌃⌘M opens a folder picker
- Reorder: drag-and-drop within the same parent; sort order is manual by default, with an option to auto-sort alphabetically or by creation date
- Duplicate: right-click > Duplicate creates a copy of the folder and all its contents with "(Copy)" appended to the name

**Drag-and-Drop**

- Folders may be dragged within the sidebar to reorder or reparent (dropping on a folder makes it a child)
- Notes may be dragged from the note list onto a folder in the sidebar
- Multi-select drag: Shift+click or ⌘+click to select multiple notes, then drag to a folder
- Drag indicator: a blue highlight on the drop target folder, a line indicator for reorder position
- Invalid drop targets (e.g., dragging a parent folder onto its own descendant) are rejected with a spring-back animation

### 4.4.2 Color-Coded Tagging System

**Tag Management**

- Tags are global (not scoped to folders) and shared across all notes
- Tag attributes: name (unique, case-insensitive), color (16 predefined + custom hex), created date, note count
- Creating tags: type a new tag name in any note's tag field; the tag is created on Enter
- Renaming: Settings > Tags > rename in-place; all notes using the tag are updated immediately
- Merging: Settings > Tags > select two or more tags > "Merge Tags"; a target tag is chosen; all notes with any of the source tags receive the target tag; source tags are deleted
- Deleting: a tag can be deleted even if notes use it; affected notes have the tag removed
- Tag count: the tag browser displays the note count for each tag, updated in real time

**Applying Tags to Notes**

- Each note may have 0–unlimited tags
- Tag field is located below the note title in the editor; typing shows an autocomplete dropdown of existing tags
- Voice tagging: during or after a dictation session, saying "tag this as [tag name]" applies the tag if the tag name exists in the library; if it does not exist, a confirmation prompt asks whether to create it
- Tag chips are displayed on note cards in the list view; overflow is indicated with "+N more"

**Tag Browser**

- A dedicated Tags section in the sidebar lists all tags with their color swatch and note count
- Clicking a tag shows all notes with that tag (cross-folder)
- Tag filtering in search is AND-combined by default (notes must have all selected tags); a toggle switches to OR logic

### 4.4.3 Automatic Dictation Persistence (Safety Net)

**Core invariant: every dictation is saved.** This is Murmur's primary differentiator over Wispr Flow and is non-negotiable. Regardless of whether text is injected into a third-party app or captured as a note, every completed dictation session creates both a `DictationSession` record AND a linked `Note`.

- **All dictation sessions** automatically create a note in the configured default folder, tagged with `#dictated` and the source app name (e.g., `#safari`, `#slack`) in metadata
- **Title generation**: first 50 characters of transcription, or datetime if transcription is empty
- **Default save location**: configurable per the user's folder of choice; defaults to "Dictation Inbox" folder (auto-created on first save)
- **Duplicate prevention**: if a note with identical content was saved within the last 60 seconds (e.g., accidental double-trigger), the second save is silently discarded and the existing note is brought into focus
- **Visibility setting**: Settings > Notes > Show Dictation Notes: In Library (default) / In Dedicated Folder Only / Hidden (accessible via search). This allows users who primarily use flow-through injection to avoid cluttering their notes library while still maintaining the safety net
- **Flow-through injections**: when text is injected into a third-party app, the linked note is marked with `sourceApp` metadata so the user can see which dictations went where. The note body contains the final (AI-processed) text; the `DictationSession` record preserves the raw transcription for comparison

### 4.4.4 Markdown Editor with Live Preview

The note editor uses a Markdown-source editing model: users write and edit CommonMark Markdown, and the editor renders a live-formatted preview alongside or inline. This approach avoids the engineering complexity of a full WYSIWYG rich text editor (custom `NSTextView`/`UITextView` subclasses with attributed string management) while providing all the formatting users need. A full WYSIWYG rich text mode is deferred to Phase 4+ as an optional upgrade.

**Editor Modes (user-configurable in Settings > Notes > Editor Mode)**

| Mode | Description |
|---|---|
| Split View (default on macOS) | Source Markdown on the left, rendered preview on the right; synchronized scrolling |
| Inline Preview | Markdown source with inline rendering — headings, bold, italic, and code are styled in-place while maintaining editable Markdown syntax (similar to Typora / iA Writer) |
| Source Only | Plain Markdown source with syntax highlighting; no preview rendering |
| Preview Only | Read-only rendered view; tap "Edit" to switch to source |

On iOS, the default is Inline Preview (split view is available on iPad in landscape).

**Supported Markdown Formatting**

| Format | Keyboard Shortcut | Markdown Syntax |
|---|---|---|
| Bold | ⌘B | `**text**` or `__text__` |
| Italic | ⌘I | `*text*` or `_text_` |
| Strikethrough | ⌘⇧X | `~~text~~` |
| Inline code | ⌘⇧C | `` `text` `` |
| H1–H6 Headings | ⌘⌥1–6 | `#` through `######` |
| Unordered list | ⌘⌥U | `- ` or `* ` at line start |
| Ordered list | ⌘⌥O | `1. ` at line start |
| Checklist | ⌘⌥T | `- [ ] ` at line start |
| Code block | ⌘⇧B | ```` ``` ```` on its own line |
| Blockquote | ⌘⌥Q | `> ` at line start |
| Horizontal rule | — | `---` on its own line |
| Link | ⌘K | `[text](url)` |
| Image | ⌘⌥I | `![alt](url or path)` |

Keyboard shortcuts insert the corresponding Markdown syntax around the selection (or at cursor if no selection).

**Code Blocks**

- Syntax highlighting for 30+ languages (Swift, Python, JavaScript, TypeScript, Rust, Go, Java, Kotlin, SQL, HTML, CSS, JSON, YAML, Bash, and others) in both source and preview modes
- Language tag after opening fence: ```` ```swift ````; auto-detection when no language is specified
- Copy button: appears on hover at the top-right of rendered code blocks in preview mode
- Line numbers: displayed in rendered preview by default, toggleable per block

**Image Handling**

- Drag-and-drop images into the editor inserts `![](image-path)` syntax and stores the image as an attachment
- Paste image from clipboard (⌘V) — same behavior
- Attach from file picker (⌘⌥I)
- Images are stored as attachments within the note data; for iCloud-synced notes, images are stored as CloudKit Assets
- Maximum image size: 10 MB per image; images larger than this are rejected with an error message
- In preview mode, images are displayed inline at their natural size, constrained to the editor width

**Checklist Behavior**

- In Inline Preview and Preview modes, checkbox items render as interactive checkboxes; clicking toggles `- [ ]` ↔ `- [x]` in the underlying Markdown source
- Checked items optionally move to the bottom of their list (configurable)
- Completed checklist items are displayed in 50% opacity in preview (configurable)

**Editor Toolbar**

A contextual toolbar appears above the keyboard on iOS and as a persistent toolbar above the editor on macOS. The toolbar contains buttons that insert Markdown formatting syntax: Bold, Italic, Strikethrough, Heading cycle, List, Checklist, Code, Link, Image, and Blockquote. A tag button and insert menu (horizontal rule, table) are also included.

**Future: WYSIWYG Rich Text Mode (Phase 4+)**

A full WYSIWYG editing mode built on custom `NSTextView` (macOS) and `UITextView` (iOS) subclasses is planned for Phase 4 as an optional upgrade. This mode would hide Markdown syntax entirely and present a traditional rich text editing experience. The underlying storage format remains Markdown — the WYSIWYG layer would serialize to/from Markdown transparently. This is a significant engineering effort and is deferred to avoid blocking the critical path.

### 4.4.5 Full-Text Search

**Search Index**

- All note content (title, body text, code block content) is indexed using a local SQLite FTS5 full-text search index
- Index is maintained incrementally; updates are written to the index within 500 ms of a note save
- Index storage: located in the app's Application Support directory; not synced via iCloud (each device maintains its own index, rebuilt from synced note content)
- Index rebuild: can be triggered manually from Settings > Storage > Rebuild Search Index; rebuild runs in the background and takes < 30 seconds for up to 10,000 notes

**Query Syntax**

- Plain text queries: substring match across title and body
- Quoted phrases: `"exact phrase"` matches the exact phrase
- Boolean operators: `AND`, `OR`, `NOT` (uppercase)
- Wildcard: `prefix*` matches any word starting with "prefix"
- Field qualifiers: `title:keyword`, `tag:tagname`, `folder:foldername`

**Search Filters**

Filters can be applied via the filter panel (accessible by clicking the filter icon in the search bar):

- **Date range**: Created After, Created Before, Modified After, Modified Before; date picker or relative presets (Today, This Week, This Month, This Year, Last 30 Days)
- **Tags**: multi-select tag picker; AND/OR logic toggle
- **Folder**: scope search to a specific folder and optionally its subfolders
- **Source app**: filter notes by the app from which they were dictated
- **Has attachments**: toggle to show only notes with images or file attachments
- **Language**: filter by detected dictation language
- **Word count**: minimum and/or maximum word count

**Search Results**

- Results are ranked by relevance (FTS5 BM25 score) by default; secondary sort is by modification date
- Each result card shows: title, snippet of matching text (with query terms highlighted), folder path, modification date, and tags
- Search-within-note: after selecting a search result, the note opens with the first match highlighted and a match navigator (Previous / Next) showing "Match X of Y"

### 4.4.6 Smart Folders

Smart folders are saved search queries that dynamically display matching notes, updated in real time as notes are created or modified.

**Creating Smart Folders**

- Any search query plus filter combination can be saved as a Smart Folder via the "Save as Smart Folder" button in the search filter panel
- Smart folders appear in the sidebar under a "Smart Folders" section, distinguished by a purple gear icon
- Smart folder attributes: name, query string, filter set, sort order, sort direction

**Built-In Smart Folders**

Murmur ships with the following pre-built smart folders (visible by default, dismissible):

- "Today" — notes created or modified today
- "This Week" — notes created or modified in the last 7 days
- "Untagged" — notes with no tags
- "Long Notes" — notes with word count > 500
- "Recent Dictations" — notes created from dictation sessions in the last 30 days

**Smart Folder Behavior**

- Smart folders are read-only (notes cannot be moved into them by dragging; moving a note into the note list area when viewing a smart folder has no effect)
- Note count badge is displayed on each smart folder in the sidebar
- Smart folders sync via iCloud; their queries and filter sets are synced but each device re-executes the query locally

### 4.4.7 Pin and Favorite Notes

- Any note can be pinned by clicking the pin icon (visible on hover in the note list) or via the right-click context menu
- Pinned notes appear at the top of all list views (including smart folders and search results) in a "Pinned" section above the regular list
- A note can be both pinned and in any folder; pinning does not move the note
- Maximum pinned notes: 20 (to prevent the pinned section from becoming unwieldy); a warning is shown when approaching the limit
- Favorites (synonym for pinned; some UI surfaces use "favorite" for discoverability); the implementation is identical

### 4.4.8 Note Templates

**Built-In Templates**

Murmur ships with pre-built templates for common use cases:

- Meeting Notes (H1 title, Date field, Attendees section, Agenda, Discussion, Action Items checklist)
- Daily Journal (Date, Mood, Highlights, Reflections, Tomorrow's Goals)
- Project Brief (Project Name, Objective, Stakeholders, Timeline, Requirements, Risks)
- Interview Notes (Candidate, Position, Date, Questions checklist, Evaluation)
- Research Note (Topic, Sources, Key Findings, Open Questions)
- Blank (no formatting)

**User-Created Templates**

- Any note can be saved as a template via the Note Menu > "Save as Template"
- Settings > Notes > Templates: a list of all templates (built-in + user-created)
- Templates are stored with the note's full Markdown content, tags, and folder assignment
- Variables in templates: template fields can be marked as `{{field_name}}` to prompt for input when the template is instantiated; a fill-in dialog appears with each field
- Importing/exporting templates as `.json` files

**Applying Templates**

- "New Note from Template" in the sidebar creates a note with the template content
- The template picker shows a preview thumbnail of the first 200 characters
- Keyboard shortcut ⌘⌥N opens the template picker directly

### 4.4.9 Export

**Export Formats**

| Format | Scope | Notes |
|---|---|---|
| Markdown | Note, folder, selection | Images exported as separate files in a subfolder; links updated to relative paths |
| PDF | Note, folder, selection | Paginated; includes metadata header (title, date, tags); custom CSS theming |
| Plain Text | Note, folder, selection | All formatting stripped; linebreaks preserved |
| JSON | Note, folder, all notes | Full data model including metadata, tags, folder path |
| HTML | Note, folder, selection | Self-contained with inline CSS; images embedded as base64 |

**Export UI**

- Export is triggered from the Note Menu > Export, or right-click on a note/folder in the sidebar
- A sheet presents format selection, scope selection, and format-specific options
- Folder exports create a ZIP archive containing all notes
- "Export All" in Settings > Data exports the complete notes database in the user's chosen format

### 4.4.10 Import

**Supported Import Formats**

- **Markdown** (`.md`, `.markdown`): parses CommonMark; front-matter YAML parsed for title, date, and tags
- **Plain text** (`.txt`): each file becomes a note; filename becomes the title
- **JSON**: Murmur's own export format; full metadata restored including tags and folder structure
- **Bear JSON** (Phase 4+): compatible with Bear note export format (for migration). Deferred from Phase 2 to reduce scope.
- **Obsidian vault** (Phase 4+): imports a folder structure as a folder hierarchy; wiki-links converted to internal links where a matching note exists; unresolved links left as plain text. Deferred from Phase 2 to reduce scope.

**Import Flow**

- Drag-and-drop files or folders onto the main window
- File > Import (⌘⇧I): file picker; supports multi-file selection
- Import preview: before confirming, a sheet shows the number of notes to be imported, any detected conflicts (notes with the same title in the same destination folder), and options for conflict resolution (skip, overwrite, create duplicate with "(Imported)" suffix)
- Import runs in the background with a progress indicator in the sidebar

### 4.4.11 Trash and Archive

**Trash**

- Deleted notes and folders move to a Trash folder accessible in the sidebar
- Trash is a system folder; notes in Trash are excluded from search by default (toggle "Include Trash" to include)
- Auto-empty Trash: configurable (Never / After 7 days / After 30 days / After 90 days); default is 30 days
- Manual empty Trash: File > Empty Trash or right-click on Trash in sidebar
- Recovering from Trash: drag note out of Trash to a folder, or right-click > Restore (restores to original folder; if original folder was deleted, restores to "All Notes" root)
- Deleted notes remain in iCloud until the Trash is emptied; CloudKit deletion propagates to all devices after emptying

**Archive**

- Archive is a distinct state from Trash; archived notes are kept indefinitely and not auto-deleted
- Archive is a system folder in the sidebar; archived notes are excluded from main search by default
- Use case: finished projects, completed meeting notes the user wants to keep but not see in active views
- Archive via right-click > Archive or keyboard shortcut ⌘⇧A
- Unarchive: right-click > Unarchive (restores to original folder or root if folder deleted)

### 4.4.12 Note Metadata

Every note carries the following metadata, displayed in an inspector panel (⌘⌥I) in the editor:

| Field | Description |
|---|---|
| Created Date | Date and time the note was first saved |
| Modified Date | Date and time of the most recent edit |
| Source App | The app that was active during dictation (if applicable) |
| Dictation Duration | Length of the dictation session that created the note (if applicable) |
| Word Count | Current word count, updated in real time while editing |
| Character Count | Current character count |
| Reading Time | Estimated reading time (words ÷ 200 wpm) |
| Languages | Languages detected during the dictation session |
| AI Provider | Which AI provider processed the dictation (if applicable) |
| Export History | Date and format of previous exports |
| Attachments | Count and total size of attached images |
| CloudKit Record ID | Displayed in developer mode only |

### 4.4.13 Sorting Options

Notes lists support the following sort criteria, all available ascending and descending:

- **Date Modified** (default): most recently modified first
- **Date Created**: newest first
- **Title**: alphabetical A–Z
- **Word Count**: longest first
- **Dictation Duration**: longest dictation first
- **Last Opened**: most recently viewed first

Sort preference is persisted per-view (each folder, smart folder, and tag view remembers its own sort setting).

### 4.4.14 Quick Note from Menu Bar

- The menu bar icon's primary action (left-click) can be configured to open a Quick Note instead of starting dictation (configurable in Settings > Menu Bar)
- Quick Note is a compact floating panel (400 × 300 pt, resizable, remembers size) that appears near the menu bar
- The panel contains a minimal editor (title optional, body required) with basic formatting support (bold, italic, code, bulleted list)
- Dictation can be started directly from the Quick Note panel (a microphone button is always visible)
- Saving: ⌘Return saves the note to the configured default folder and dismisses the panel; Escape dismisses without saving (with a confirmation if content is non-empty)
- Quick notes are tagged with a configurable default tag (e.g., "Quick Note") for easy filtering

---

## 4.5 System-Wide Text Injection

### 4.5.1 macOS Accessibility API Integration

Text injection via the macOS Accessibility API is the primary injection method for macOS. It provides reliable, cursor-aware, undo-compatible text insertion in standard macOS applications.

**Implementation**

- Murmur uses `AXUIElement` APIs to identify the focused text element in the frontmost application at the time the dictation session ends
- The focused element is obtained via `AXUIElementCreateSystemWide()` → `kAXFocusedUIElementAttribute` → verify `kAXValueAttribute` is writable
- Text insertion: `AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute, range)` followed by `AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute, editedText)`
- This approach replaces the current selection (if any) with the dictated text; if the selection is empty (a cursor position), it inserts at the cursor

**Accessibility Permission**

- On first use of text injection, Murmur requests Accessibility permission via `AXIsProcessTrusted()`; if not granted, a system permission prompt is shown
- Settings > Permissions shows the current Accessibility permission status with a direct "Open System Settings" button

**Focused Element Detection**

- Before injection, the system verifies the focused element is a text input by checking `kAXRoleAttribute` for values: `AXTextField`, `AXTextArea`, `AXComboBox`, `AXSearchField`
- If the focused element is not a text input, injection is aborted and the clipboard fallback is used instead, with a notification

### 4.5.2 Clipboard Fallback

When the Accessibility API is unavailable or the target element does not support it, Murmur falls back to clipboard-based injection.

**Clipboard Injection Sequence**

1. Save current clipboard contents to a temporary variable
2. Write the edited transcription text to the clipboard
3. Simulate ⌘V keypress via `CGEventCreateKeyboardEvent` to paste
4. After 200 ms (configurable), restore the original clipboard contents

**Clipboard Preservation**

- The original clipboard is restored exactly, including its UTI type information
- If the original clipboard contained an image or other non-text type, restoration is complete
- If clipboard restoration fails (e.g., the clipboard was modified by another app in the 200 ms window), the transcription text remains on the clipboard and a notification informs the user

**Clipboard Fallback Triggers**

- Target app does not expose `AXValue` as writable
- Accessibility permission not granted
- Per-app profile explicitly configured to use clipboard injection
- App is on the clipboard-only list in Settings > App Profiles > Exceptions

### 4.5.3 Per-App Behavior Configuration

The injection method is configurable per application in the App Profile (see 4.3.5). Additionally, a global injection preference is set in Settings > Text Injection:

- **Prefer Accessibility API** (default): uses AX API where available, falls back to clipboard
- **Always Use Clipboard**: uses clipboard injection universally
- **Ask Each Time**: shows an injection method prompt in the HUD before each injection

### 4.5.4 App Detection and Context Awareness

At the moment dictation activation begins, Murmur captures:

- The frontmost application's bundle identifier and display name
- The focused element's role and application-specific identifier (where exposed via accessibility)
- The text surrounding the cursor (up to 500 characters before and 500 characters after), captured via `kAXSelectedTextRangeAttribute` manipulation — this context is sent to the AI editing pipeline for tone and style decisions

**Context Capture Privacy**

- Surrounding text context is used only for the current AI editing call and is not stored
- Context capture can be disabled entirely in Settings > Privacy > "Capture Text Context"
- When disabled, the AI pipeline receives only the dictated text and the app name, without surrounding context

### 4.5.5 Cursor Position Preservation

After text injection via the Accessibility API:

- The cursor is placed at the end of the injected text by setting `kAXSelectedTextRangeAttribute` to a zero-length range immediately following the inserted text
- The cursor position is consistent regardless of whether text was selected before dictation (selected text is replaced, cursor ends up after the replacement)
- For applications that do not expose cursor position via accessibility (fallback to clipboard injection), cursor behavior is application-dependent

### 4.5.6 Multi-Line Injection

- Multi-paragraph transcriptions (containing `\n\n`) are injected as multiple paragraphs, with the application's native paragraph separator (accessible apps expose this via `AXParagraphAttribute`; clipboard injection uses `\n` universally)
- Line break handling: single `\n` in the transcription is treated as a soft line break; `\n\n` as a paragraph break; the AI editing pipeline normalizes line breaks according to the target app's context (e.g., in email compose, paragraphs are separated by blank lines)

### 4.5.7 Undo Support

**Accessibility API Path**

- For apps that support it, Murmur wraps the text injection in a single undo group by sending `kAXNotificationUIElementDestroyed` notifications appropriately or by using app-specific undo registration where exposed
- In practice, undo behavior depends on the target application; Murmur cannot guarantee single-step undo in all apps
- The HUD offers a dedicated "Undo Injection" button (⌘Z equivalent) for 10 seconds after injection, which re-focuses the target element, selects the injected text, and deletes it — restoring the pre-injection cursor state

**Clipboard Path**

- Undo behavior is entirely controlled by the target application; clipboard paste is treated as a single undo action in most apps
- The same post-injection "Undo Injection" HUD button is available and uses the same selection-and-delete approach

---

## 4.6 Developer Features

### 4.6.1 Code Syntax Awareness Mode

Code mode is activated automatically when the target app is an IDE or code editor (detected by bundle ID; configurable list), or manually via the HUD toggle or Settings > App Profiles.

**Identifier Casing Conventions**

The user selects the active casing convention in their App Profile or via a quick toggle in the HUD:

| Convention | Trigger | Example |
|---|---|---|
| camelCase | "camel case" or auto | "my variable name" → `myVariableName` |
| PascalCase | "pascal case" or auto | "my class name" → `MyClassName` |
| snake_case | "snake case" or auto | "my function name" → `my_function_name` |
| SCREAMING_SNAKE | "screaming snake" | "my constant" → `MY_CONSTANT` |
| kebab-case | "kebab case" | "my css class" → `my-css-class` |
| dot.notation | "dot notation" | "my config key" → `my.config.key` |

- Auto-detection: when "Auto" is selected, Murmur infers the convention from the surrounding code context captured by the Accessibility API
- Mixed identifiers in a single dictation session are supported: "function camel case create user session and return snake case user data" → `function createUserSession() and return user_data`

### 4.6.2 Operator Verbalization

A curated dictionary of operator voice mappings is applied during post-processing in code mode:

| Spoken | Output | Context |
|---|---|---|
| "equals equals" | `==` | General |
| "triple equals" | `===` | JavaScript |
| "not equals" | `!=` | General |
| "arrow" | `->` | Swift/Rust/C++ |
| "fat arrow" | `=>` | JavaScript |
| "double colon" | `::` | Rust/C++ |
| "bang" | `!` | General |
| "ampersand" | `&` | General |
| "pipe" | `\|` | General |
| "double pipe" | `\|\|` | General |
| "double ampersand" | `&&` | General |
| "question mark" | `?` | General |
| "tilde" | `~` | General |
| "backtick" | `` ` `` | General |
| "at sign" | `@` | General |
| "hash" | `#` | General |
| "ellipsis" | `...` | Swift/JS |
| "range operator" | `..<` | Swift |

Users may add custom operator mappings in Settings > Developer > Operator Mappings.

### 4.6.3 Bracket and Delimiter Insertion

| Spoken | Output |
|---|---|
| "open paren" / "close paren" | `(` / `)` |
| "open bracket" / "close bracket" | `[` / `]` |
| "open brace" / "close brace" | `{` / `}` |
| "open angle" / "close angle" | `<` / `>` |
| "parens" (paired) | `()` with cursor inside |
| "brackets" (paired) | `[]` with cursor inside |
| "braces" (paired) | `{}` with cursor inside |
| "single quote" | `'` |
| "double quote" | `"` |
| "backtick string" | `` ` `` |

Paired delimiters place the cursor between them after injection (Accessibility API only).

### 4.6.4 Language-Specific Dictation Profiles

Users may define or select a language-specific dictation profile in Settings > Developer > Code Profiles. Murmur ships profiles for:

- Swift (PascalCase types, camelCase methods/properties, `->` return arrow, `guard`/`let`/`var` keywords)
- Python (snake_case functions/variables, PascalCase classes, `:` block opener, `def`/`class` keywords)
- JavaScript / TypeScript (camelCase variables, PascalCase classes, `=>` fat arrow, `const`/`let` keywords)
- Rust (snake_case functions, PascalCase types, `::` path separator, `fn`/`impl`/`struct` keywords)
- Go (camelCase unexported, PascalCase exported, `:=` short declaration)
- Java / Kotlin (PascalCase classes, camelCase methods)
- SQL (UPPERCASE keywords: `SELECT`, `FROM`, `WHERE`, `JOIN`, `GROUP BY`, etc.)
- HTML/CSS (kebab-case class names, lowercase tags)

Each profile stores: default casing convention, keyword list (automatically uppercased/lowercased), operator mappings override, and snippet expansions for common boilerplate.

### 4.6.5 Terminal and Shell Command Interpretation

When the target app is Terminal, iTerm2, Ghostty, or a recognized shell environment:

- Code mode activates automatically
- Command vocabulary: common Unix/shell keywords are recognized and formatted correctly (e.g., "pipe grep" → `| grep`, "redirect to file" → `>`, "append to file" → `>>`)
- Flag verbalization: "dash dash verbose" → `--verbose`, "dash r" → `-r`
- Path components: "slash users slash home" → `/users/home`
- Shell completion: dictating a partial command does not trigger auto-complete in the terminal; text is only injected when the session ends

---

## 4.7 Future Scope (Documented, Not v1)

The following features are explicitly out of scope for v1.0 but are documented here to ensure architectural decisions do not foreclose their implementation.

### 4.7.1 Shared Dictionaries and Snippets (Team Collaboration)

Team workspaces where multiple users can share a personal dictionary, snippet library, and style presets. Requires a server-side component (or iCloud Family Sharing extension) and a team member management UI. Conflict resolution policy (team admin overrides individual) must be defined.

### 4.7.2 Usage Analytics Dashboard (Opt-In)

An in-app dashboard showing: words dictated per day/week/month, most-used languages, AI edits applied per session, top filler words removed, most-used snippets, and time saved estimates. Entirely local computation; no data leaves the device. Users must explicitly opt in.

### 4.7.3 Speaker Diarization for Multi-Speaker Notes

Ability to identify and label multiple speakers in a recording (e.g., meeting notes). Requires Apple's future speaker diarization API or integration with a cloud provider that supports it. Output format: labeled paragraphs with speaker IDs.

### 4.7.4 Meeting Recording and Transcription

A dedicated recording mode that transcribes long-form audio (meetings, lectures, interviews) with timestamps, chapter markers, and auto-generated summaries. Requires audio file storage, a different UI paradigm from live dictation, and handling of very long transcriptions (> 1 hour).

### 4.7.5 Plugin and Extension Marketplace

A sandboxed plugin system allowing third-party developers to add: custom AI providers, export formats, note editor extensions, and custom voice commands. Requires a plugin API design, code signing requirements, and a distribution channel.

---

---

# Section 5: User Stories and Acceptance Criteria

---

## Epic 1: Dictation

---

**US-001: Activate Dictation with Hold-to-Dictate**
As a professional user, I want to hold the Fn key to start and stop dictation, so that I can quickly insert text into any focused field without lifting my hands from the keyboard.

**Acceptance Criteria:**
- [ ] Pressing and holding the Fn key begins a dictation session within 80 ms
- [ ] Releasing the Fn key ends the session and triggers the AI editing pipeline
- [ ] Releasing the Fn key before 300 ms minimum hold duration does not start a session
- [ ] The menu bar icon transitions to an animated waveform state during recording
- [ ] A floating HUD appears within 100 ms of session start showing waveform and live transcription preview
- [ ] Releasing the key while no speech has been detected produces an empty session (no injection, no error)
- [ ] Holding the configured secondary key activates dictation when a Fn key conflict is detected

---

**US-002: Activate Dictation with Toggle Mode**
As a long-form writer, I want to press a key once to start dictation and again to stop, so that I can dictate extended passages without holding a key.

**Acceptance Criteria:**
- [ ] A single configured keypress starts a dictation session and shows a persistent HUD
- [ ] A second configured keypress ends the session and triggers processing
- [ ] A session duration timer (MM:SS) is displayed in the HUD throughout the session
- [ ] At 80% of the configured maximum session duration, a warning indicator appears in the HUD
- [ ] At 100% of the configured maximum session duration, the session ends automatically and processing begins
- [ ] The user can extend the session duration by clicking "Extend 5 min" in the HUD before the timeout
- [ ] If focus leaves all windows during a toggle session, the HUD remains visible on screen as a floating panel

---

**US-003: View Real-Time Transcription Preview**
As a user, I want to see a live transcription preview while I speak, so that I can verify the engine is capturing my words accurately before they are injected.

**Acceptance Criteria:**
- [ ] The HUD displays interim transcription results word-by-word as the speech engine produces them
- [ ] Words currently being processed appear at 50% opacity; finalized words appear at full opacity
- [ ] The preview scrolls automatically when the text exceeds 5 visible lines
- [ ] Words with confidence below 0.65 are underlined in amber in the preview
- [ ] A waveform visualization is displayed alongside the text preview throughout the session
- [ ] The waveform renders at a minimum of 30 fps without dropping frames during normal dictation

---

**US-004: Dictate in a Non-English Language**
As a non-English-speaking professional, I want to set my dictation language to my native language, so that I receive accurate transcription in that language without any English interference.

**Acceptance Criteria:**
- [ ] Settings > Dictation > Language presents a searchable list of all supported locales (≥ 110)
- [ ] Selecting a locale persists the setting across app restarts
- [ ] The speech engine uses the selected locale for subsequent sessions
- [ ] A language requiring a model download shows a download badge; the download can be initiated from the picker
- [ ] After the model downloads, dictation in that language produces a transcription in that language without switching to the fallback engine
- [ ] The 5 most recently used languages appear at the top of the language picker

---

**US-005: Dictate in Mixed Languages**
As a bilingual user, I want to dictate using two languages in the same sentence, so that I can express myself naturally without pausing to switch language modes.

**Acceptance Criteria:**
- [ ] Settings > Dictation > Mixed Language provides a toggle to enable mixed-language dictation
- [ ] The language roster picker enforces a minimum of 2 and maximum of 5 languages
- [ ] A test dictation session with utterances in two roster languages produces a transcription containing both languages correctly
- [ ] Language transitions within a sentence require no special pause or command
- [ ] The note metadata for the session lists all detected languages
- [ ] The AI editing pipeline receives the list of detected languages and applies appropriate grammar rules per language segment

---

**US-006: Use Whisper Mode for Quiet Environments**
As a user working in an open office, I want to speak quietly and still receive accurate transcription, so that I do not disturb my colleagues while dictating.

**Acceptance Criteria:**
- [ ] Whisper mode is activatable from the HUD microphone button, a configurable keyboard shortcut, and a voice command
- [ ] Activating whisper mode applies a software input gain boost (default +12 dB) to the audio input
- [ ] The HUD and menu bar icon display a distinct whisper mode indicator
- [ ] Speech spoken at approximately 30% normal conversational volume is transcribed with accuracy ≥ 85% of normal-volume accuracy (measured on standard test sentences)
- [ ] Whisper mode state resets to the user's configured default at the start of each new session (unless "sticky whisper mode" is enabled)
- [ ] A one-time informational tooltip about potential accuracy tradeoffs is shown the first time whisper mode is activated

---

**US-007: Select and Configure Microphone Input**
As a user with multiple audio input devices, I want to choose which microphone Murmur uses, so that I can select the device best suited for dictation.

**Acceptance Criteria:**
- [ ] Settings > Audio > Input Device lists all currently available audio input devices with name and type icon
- [ ] Selecting a device persists the selection and uses it for all subsequent sessions
- [ ] A software gain slider is available per device (range: –10 dB to +20 dB)
- [ ] A real-time input level meter is displayed in the Audio Settings panel
- [ ] Connecting a new audio input device does not automatically switch the active device; a notification informs the user
- [ ] Disconnecting the active input device mid-session pauses recording, displays an alert, and preserves partial transcription

---

**US-008: Recover a Partial Session After a Crash**
As a user, I want to recover dictated content after an unexpected app crash, so that I do not lose work during a long dictation session.

**Acceptance Criteria:**
- [ ] Partial transcription text is saved to a recovery file at minimum every 10 seconds during an active session
- [ ] On the next app launch after a crash, a recovery banner offers the option to view and complete transcription of the recovered session
- [ ] Accepting recovery produces a note (or HUD preview) with the partial transcription
- [ ] Dismissing the recovery banner discards the recovery file (with a confirmation prompt)
- [ ] Recovery is offered once per crashed session; subsequent launches do not re-offer the same recovery

---

**US-009: View Session History**
As a user, I want to review my recent dictation sessions from the menu bar, so that I can retrieve or re-inject text from a previous session without re-dictating.

**Acceptance Criteria:**
- [ ] The menu bar menu contains a History submenu showing the last 50 sessions
- [ ] Each history entry displays: timestamp, duration, word count, and source application
- [ ] Clicking a history entry shows the full text of that session in a popover
- [ ] A "Save as Note" button in the history entry popover saves the session text to the default notes folder
- [ ] A "Re-inject" button re-injects the session text into the currently focused text field
- [ ] Sessions older than the configured retention period (default 30 days) are automatically removed from the history

---

**US-010: Enable Always-On Dictation Mode**
As a power user, I want the app to listen continuously and transcribe when it detects my voice, so that I can dictate without any activation gesture.

**Acceptance Criteria:**
- [ ] Always-on mode requires explicit user consent with a privacy disclosure on first enable
- [ ] An orange dot is permanently displayed in the menu bar whenever always-on mode is active and the microphone is open
- [ ] Voice activity detection begins transcribing automatically when speech exceeds the configured sensitivity threshold
- [ ] A configurable silence timeout (0.5–5.0 seconds) ends the current utterance and triggers the pipeline
- [ ] Always-on mode automatically suspends when battery level drops below 20% unless the user has explicitly overridden this
- [ ] Always-on mode can be paused and resumed from the menu bar without fully disabling the setting

---

## Epic 2: AI Editing

---

**US-011: Remove Filler Words Automatically**
As a professional communicator, I want filler words like "um," "uh," and "you know" removed from my transcription automatically, so that my injected text reads cleanly without manual editing.

**Acceptance Criteria:**
- [ ] After a session containing the words "um," "uh," "er," "you know," "like" (as discourse marker), and "basically," none of these appear in the injected output
- [ ] The removal correctly handles fillers at sentence boundaries without creating capitalization errors
- [ ] Context-dependent fillers (e.g., "I really like this") are preserved when "like" is used as a legitimate word
- [ ] The filler word list is editable in Settings > AI Editing > Filler Words; adding a custom word causes it to be removed in subsequent sessions
- [ ] Filler removal can be disabled globally or per app profile; when disabled, fillers appear in the injected text

---

**US-012: Correct Backtracked Speech**
As a user who revises thoughts while speaking, I want the app to detect when I say "no wait" or "scratch that" and remove the preceding clause, so that only my intended final statement is injected.

**Acceptance Criteria:**
- [ ] Dictating "I'll send it Thursday, no wait, Friday" injects only "I'll send it Friday"
- [ ] Dictating "scratch that" with no corrective content following it removes the preceding clause
- [ ] The HUD preview briefly shows the deleted text with strikethrough before it disappears (within 1.5 seconds)
- [ ] The backtrack trigger phrase itself does not appear in the final injected text
- [ ] All default trigger phrases (no wait, scratch that, delete that, never mind, let me rephrase, correction, I meant to say) function correctly
- [ ] Custom trigger phrases added in Settings are recognized in subsequent sessions
- [ ] An ambiguous backtrack (unclear deletion scope) is resolved by the AI backend and the result matches user intent in ≥ 90% of test cases

---

**US-013: Apply Tone Adaptation for Different Applications**
As a professional who dictates in both email and Slack, I want my text automatically formatted to match the appropriate tone for each application, so that my communications always sound contextually appropriate.

**Acceptance Criteria:**
- [ ] Dictating the same content in Mail produces a formally worded output with full sentences and no contractions
- [ ] Dictating the same content in Slack produces a friendly, contraction-using, shorter-sentence output
- [ ] App profile tone settings are applied automatically based on the frontmost app when dictation starts
- [ ] Changing the tone profile in the App Profile settings affects subsequent sessions in that app immediately
- [ ] The HUD displays the active tone profile name during processing
- [ ] The Raw/Edited toggle in the HUD shows the pre-tone-adaptation text as "Raw" for comparison

---

**US-014: Issue Inline Voice Commands**
As a user, I want to say "make this more concise" or "translate to French" during dictation, so that the AI transforms my text according to my spoken instruction without me opening any menu.

**Acceptance Criteria:**
- [ ] Dictating "tell them the meeting is at 3 PM, translate to French" injects the French translation of the meeting statement
- [ ] Dictating "I need three bullet points about our Q3 goals, make it a numbered list" injects a numbered list with three items
- [ ] The command phrase itself does not appear in the injected output
- [ ] When command confidence is below 0.75, the HUD shows a disambiguation prompt that auto-dismisses to "apply" after 3 seconds
- [ ] Custom commands configured in Settings > AI Editing > Custom Commands are recognized in sessions
- [ ] Frequently used commands (≥ 3 times in 7 days) appear in a Quick Commands section in the HUD for one-click access

---

**US-015: Configure the AI Provider**
As a user, I want to enter my OpenAI API key and select the model to use, so that Murmur uses my preferred AI provider for all editing tasks.

**Acceptance Criteria:**
- [ ] Settings > AI Editing > Providers presents a list of all available providers
- [ ] Entering an API key and clicking "Verify Key" makes a test call and reports success or failure with a specific error message
- [ ] API keys are stored in the macOS Keychain and are not readable as plaintext from any settings UI after initial entry
- [ ] A model selection dropdown is available for each provider; only supported models for that provider are listed
- [ ] The provider order can be changed by drag-and-drop; the topmost provider is used first
- [ ] The configured provider is used in the next dictation session after saving settings

---

**US-016: Use a Fallback AI Provider**
As a user, I want the app to automatically fall back to my secondary AI provider if the primary one is unavailable, so that AI editing continues working even if one service is down.

**Acceptance Criteria:**
- [ ] When the primary provider returns a network error or API error, the next provider in the chain is tried automatically
- [ ] The fallback occurs transparently; text is still injected without user intervention
- [ ] An optional notification ("Fell back to [Provider Name]") appears if the setting is enabled
- [ ] If all providers in the chain fail, the raw transcription is injected with a non-intrusive banner notification
- [ ] A provider that fails 5 times in 10 minutes is temporarily suspended from the chain for 5 minutes; the Settings UI shows a "Temporarily Suspended" badge on that provider
- [ ] Manually clicking "Retry" in the Settings provider card restores the provider to the active chain

---

**US-017: View and Inject Raw vs. Edited Output**
As a user, I want to see what the AI changed and choose whether to inject the raw or edited version, so that I maintain control over what text enters my documents.

**Acceptance Criteria:**
- [ ] After pipeline completion, the HUD shows a Raw / Edited toggle defaulting to Edited
- [ ] Switching to Raw shows the verbatim transcription (post-backtrack resolution, pre-AI editing)
- [ ] A diff view (⌘D) highlights additions in green and deletions in red
- [ ] The user can manually edit the text in either view before clicking "Insert" to inject
- [ ] Pressing ⌘Return in the HUD preview injects the currently displayed text (raw or edited)
- [ ] The Raw / Edited preference is remembered per app profile

---

**US-018: Use Apple Intelligence as the AI Provider**
As a privacy-conscious user without cloud API keys, I want to use Apple Intelligence for AI editing without any internet connection, so that my dictation data never leaves my device.

**Acceptance Criteria:**
- [ ] Apple Intelligence is listed as a provider option and is automatically selected when no cloud API keys are configured
- [ ] A "Fully Local" badge is displayed in the AI status indicator when Apple Intelligence is the active provider
- [ ] Grammar correction, filler removal, and tone adaptation function correctly using Apple Intelligence
- [ ] A command like "make this more concise" is processed using available Writing Tools actions
- [ ] If Apple Intelligence is unavailable on the device, a clear explanation is shown in Settings and the provider is listed as "Unavailable"
- [ ] No network request is made during an Apple Intelligence provider editing session (verifiable via a proxy or network monitor)

---

## Epic 3: Notes and Organization

---

**US-019: Create a Nested Folder Structure**
As a knowledge worker, I want to create folders within folders to organize my notes hierarchically, so that my notes mirror the structure of my projects and areas of responsibility.

**Acceptance Criteria:**
- [ ] Right-clicking a folder in the sidebar shows a "New Subfolder" option that creates a child folder
- [ ] Folder nesting is supported to at least 10 levels of depth
- [ ] Folders can be renamed by double-clicking the folder name in the sidebar and pressing Return to confirm
- [ ] Dragging a folder onto another folder in the sidebar makes it a child of the drop target
- [ ] Dragging a folder onto its own descendant is rejected with a spring-back animation
- [ ] Deleting a folder moves all contained notes to Trash and shows a confirmation dialog with the note count

---

**US-020: Create and Apply Color-Coded Tags**
As a user, I want to create custom tags with colors and apply multiple tags to a note, so that I can cross-reference notes across folder boundaries using a visual tagging system.

**Acceptance Criteria:**
- [ ] Typing a new tag name in the note's tag field and pressing Enter creates the tag and applies it to the note
- [ ] The tag appears in the sidebar Tags section immediately after creation
- [ ] Up to 16 predefined colors and a custom hex input are available for tag color selection
- [ ] A note can have an unlimited number of tags applied
- [ ] Renaming a tag in Settings > Tags updates the tag name on all notes that use it
- [ ] Merging two tags in Settings > Tags combines all notes from both tags under the target tag and removes the source tags
- [ ] Deleting a tag removes it from all notes without deleting the notes themselves

---

**US-021: Auto-Save a Dictation Session as a Note**
As a user who dictates frequently, I want the app to automatically save each dictation session as a note in my Inbox folder, so that I never lose a dictation without having to explicitly save it.

**Acceptance Criteria:**
- [ ] With Auto-Save set to "Always," every completed dictation session creates a note in the configured default folder
- [ ] The note title is set to the first 50 characters of the transcription or a datetime stamp if the transcription is empty
- [ ] The note metadata includes source app, dictation duration, and detected language
- [ ] With Auto-Save set to "Ask," a non-blocking banner appears for 8 seconds after each session offering "Save as Note"
- [ ] The banner auto-dismisses without saving if no action is taken
- [ ] If an identical note was saved within the last 60 seconds, the duplicate is silently discarded and the existing note is brought into focus
- [ ] With Auto-Save set to "Never," no note is created automatically; the user may save from the HUD

---

**US-022: Format a Note with Markdown**
As a writer, I want to use bold, italic, headings, lists, and code blocks in my notes, so that my notes are well-structured and easy to read.

**Acceptance Criteria:**
- [ ] ⌘B wraps selected text in `**bold**`; ⌘I wraps in `*italic*`; ⌘⌥1 inserts `# ` heading prefix
- [ ] Markdown syntax renders in the live preview pane (or inline in Inline Preview mode)
- [ ] A fenced code block (``` on its own line) renders with syntax highlighting in preview
- [ ] The language of a code block can be specified after the opening backticks; auto-detection is available in preview
- [ ] A one-click copy button appears on hover over any code block in preview
- [ ] Typing `- [ ] ` at the start of a line creates a checklist item rendered with a functional checkbox in preview
- [ ] Checking a checklist item in preview updates the Markdown source to `- [x]`
- [ ] Pasting Markdown-formatted text from the clipboard is inserted as-is and rendered in preview

---

**US-023: Search Notes with Filters**
As a user with hundreds of notes, I want to search for notes by keyword and refine results by date, tag, and folder, so that I can find any note within seconds.

**Acceptance Criteria:**
- [ ] The search bar in the main window performs a full-text search across all note titles and body text
- [ ] Search results appear within 300 ms for a library of up to 10,000 notes
- [ ] Results display a snippet of the matching text with query terms highlighted
- [ ] The filter panel allows filtering by date range, tags (AND/OR), folder, source app, and has-attachments toggle
- [ ] Applying multiple filters narrows results to notes matching all filter conditions (AND by default)
- [ ] Searching with `title:keyword` returns only notes with the keyword in the title
- [ ] After opening a note from search results, matching terms are highlighted within the note body with a Previous/Next navigator

---

**US-024: Create a Smart Folder**
As an organized user, I want to save a search query as a smart folder that automatically stays up to date, so that I can quickly access dynamically curated collections of notes.

**Acceptance Criteria:**
- [ ] Any search query plus filter combination can be saved as a Smart Folder via a "Save as Smart Folder" button in the filter panel
- [ ] The saved smart folder appears in the sidebar under a "Smart Folders" section with a gear icon
- [ ] The note count in the smart folder updates in real time as notes are created, modified, or deleted
- [ ] A smart folder can be renamed and its query/filters edited by right-clicking in the sidebar > "Edit Smart Folder"
- [ ] The 5 built-in smart folders (Today, This Week, Untagged, Long Notes, Recent Dictations) are present on first launch
- [ ] Smart folder configurations sync via iCloud to all devices

---

**US-025: Export Notes to Markdown and PDF**
As a user who shares notes with others, I want to export individual notes or entire folders as Markdown files or PDFs, so that I can share my notes in universally compatible formats.

**Acceptance Criteria:**
- [ ] Right-clicking a note and selecting Export presents a format picker (Markdown, PDF, Plain Text, JSON, HTML)
- [ ] Exporting a note as Markdown produces a valid `.md` file (the native storage format, so this is essentially a direct export)
- [ ] Exporting a note as PDF produces a paginated PDF with a metadata header (title, date, tags)
- [ ] Images within the note are embedded in the PDF and exported to a subfolder for Markdown export with updated relative links
- [ ] Exporting a folder produces a ZIP archive containing all notes in the chosen format
- [ ] A "Export All Notes" option in Settings > Data exports the complete notes database
- [ ] Large folder exports (> 100 notes) run in the background with a progress indicator

---

**US-026: Import Notes from Markdown Files**
As a user migrating from another note-taking app, I want to import my existing Markdown files into Murmur, so that I can consolidate all my notes in one place without losing formatting or metadata.

**Acceptance Criteria:**
- [ ] Dragging a `.md` file onto the main window triggers an import dialog
- [ ] File > Import (⌘⇧I) opens a file picker supporting multi-file and folder selection
- [ ] Imported Markdown is rendered correctly in the live preview; headings, lists, code blocks, bold, and italic display as expected
- [ ] YAML front-matter containing `title`, `date`, and `tags` fields is parsed and applied to the note metadata
- [ ] The import preview dialog shows the number of notes to be imported and any conflicts
- [ ] Conflict resolution options: Skip, Overwrite, and Duplicate with "(Imported)" suffix are all available
- [ ] (Phase 4+) Importing an Obsidian vault folder preserves the folder structure as nested folders within the app

---

**US-027: Recover a Deleted Note from Trash**
As a user, I want to recover notes I accidentally deleted from the Trash, so that I do not permanently lose important content from a misclick.

**Acceptance Criteria:**
- [ ] Deleting a note moves it to the Trash folder, which is visible in the sidebar
- [ ] Notes in Trash are excluded from search results by default; a toggle in the search filter panel includes them
- [ ] Right-clicking a note in Trash > "Restore" returns it to its original folder
- [ ] If the original folder was deleted, the restored note appears at the root "All Notes" level
- [ ] The Trash auto-empties after the configured retention period (default 30 days) with a warning notification 24 hours before permanent deletion
- [ ] "Empty Trash" is accessible via File menu and right-click on the Trash folder; requires confirmation before permanent deletion

---

**US-028: Use a Note Template**
As a user who takes recurring meeting notes, I want to create a note from a template that pre-populates sections for Attendees, Agenda, and Action Items, so that I start every meeting note consistently formatted.

**Acceptance Criteria:**
- [ ] ⌘⌥N opens the template picker showing all available templates (built-in and user-created)
- [ ] The template picker shows a preview of the first 200 characters for each template
- [ ] Selecting a template creates a new note pre-populated with the template's content and formatting
- [ ] Any note can be saved as a custom template via Note Menu > "Save as Template"
- [ ] Templates containing `{{field_name}}` variables prompt the user to fill in each field before creating the note
- [ ] User-created templates can be exported as `.json` and imported on another device

---

**US-029: Use Quick Note from the Menu Bar**
As a user who wants to capture a thought without opening the full app, I want to open a compact Quick Note panel from the menu bar, so that I can capture ideas instantly with minimal interruption to my workflow.

**Acceptance Criteria:**
- [ ] Clicking the menu bar icon (when configured as Quick Note) opens a compact floating panel within 150 ms
- [ ] The panel contains a title field (optional), a body editor with basic formatting, and a microphone button for dictation
- [ ] ⌘Return saves the note to the configured default folder and dismisses the panel
- [ ] Escape dismisses the panel; if the body is non-empty, a confirmation prompt prevents accidental dismissal
- [ ] The Quick Note panel remembers its last size and position between invocations
- [ ] A configurable default tag (e.g., "Quick Note") is automatically applied to all notes created via the Quick Note panel

---

**US-030: View Note Metadata**
As a user, I want to see when a note was created and modified, how many words it contains, and which app it was dictated in, so that I have full context about each note's history and origin.

**Acceptance Criteria:**
- [ ] The metadata inspector (⌘⌥I) opens a side panel within the note editor displaying all metadata fields
- [ ] Created Date, Modified Date, Word Count, and Source App are always displayed
- [ ] For notes created from dictation, Dictation Duration, Detected Languages, and AI Provider are also displayed
- [ ] Word Count updates in real time while the user edits the note
- [ ] Reading Time is calculated as word count ÷ 200 wpm and displayed in the inspector
- [ ] The inspector panel is collapsible and its open/closed state persists across sessions

---

## Epic 4: Settings and Configuration

---

**US-031: Manage the Personal Dictionary**
As a user with industry-specific terminology, I want to add words and phrases to my personal dictionary so that the speech engine and AI transcribe them correctly every time.

**Acceptance Criteria:**
- [ ] Settings > Personalization > Dictionary presents a searchable list of all dictionary entries
- [ ] The user can add a new entry specifying the spoken form, the intended transcription, and an optional phonetic hint
- [ ] A word manually corrected in the HUD preview more than once is automatically added to the personal dictionary with a notification
- [ ] The dictionary supports multiple entry types: simple substitution, proper noun, acronym, and phrase
- [ ] Importing a `.csv` file with columns `spoken_form,transcription` bulk-adds entries
- [ ] Exporting the dictionary produces a `.csv` file with all current entries
- [ ] Deleting an entry from the dictionary takes effect in the next dictation session

---

**US-032: Create and Use Snippets**
As a user who frequently types recurring phrases, I want to define voice triggers that expand into full text templates, so that I can insert boilerplate content with a short spoken phrase.

**Acceptance Criteria:**
- [ ] Settings > Personalization > Snippets allows creating a snippet with a name, trigger phrase(s), and expansion text
- [ ] Dictating a snippet's trigger phrase during a session causes the expansion to be substituted in the output
- [ ] A snippet expansion containing `{{date}}` inserts the current date in the user's locale format
- [ ] A snippet expansion containing `{{input: "Your name"}}` opens a mini popover prompting for user input before injection
- [ ] When a trigger is detected, an expansion confirmation briefly appears in the HUD; pressing Escape injects the literal trigger phrase instead
- [ ] Snippets can be exported as `.json` and imported on another device
- [ ] Two snippets sharing a trigger phrase show a conflict badge in the Snippets settings, preventing ambiguous expansion

---

**US-033: Configure a Per-App Behavior Profile**
As a developer, I want Xcode to use code mode with PascalCase for types and camelCase for methods, while Mail uses formal tone with filler removal, so that each app behaves optimally for its context.

**Acceptance Criteria:**
- [ ] Settings > App Profiles presents a list of existing app profiles sorted by most recently used
- [ ] Creating a new profile opens a picker showing installed applications; selecting one creates a profile for that app
- [ ] Each profile has independent settings for: tone preset, AI editing on/off, filler removal on/off, code mode on/off, and injection method
- [ ] After the first dictation session in a new app, a prompt offers to create a profile for that app
- [ ] Changes to an app profile take effect in the next dictation session in that app
- [ ] Deleting an app profile reverts that app to global default settings

---

**US-034: Configure the Activation Key**
As a user who uses the Fn key for other purposes, I want to change the dictation activation key to Right Option, so that there is no conflict with my existing keyboard shortcuts.

**Acceptance Criteria:**
- [ ] Settings > Dictation > Activation Key presents a key capture field; clicking it then pressing any key or modifier combination sets it as the new activation key
- [ ] Supported activation keys include: Fn, Right Option, Right Command, Caps Lock, and any standard key used as a hold-to-activate trigger
- [ ] If the selected key conflicts with a system or app shortcut, a warning is displayed with the conflicting shortcut described
- [ ] The secondary fallback key can be independently configured
- [ ] The new activation key works within the next 5 seconds of being saved (no app restart required)
- [ ] Resetting to defaults restores Fn as the activation key

---

**US-035: Calibrate Microphone for the Current Environment**
As a user in a noisy environment, I want to run the voice calibration wizard so that Murmur sets optimal gain and VAD threshold for my current surroundings.

**Acceptance Criteria:**
- [ ] Settings > Audio > Calibrate opens a guided wizard with 15 calibration sentences
- [ ] The wizard displays each sentence, records the user reading it, and shows a progress indicator
- [ ] Completing the wizard updates the gain level and VAD threshold for the selected microphone
- [ ] The user can skip calibration and complete it later from Settings
- [ ] Calibration results can be saved as a named environment profile (e.g., "Home Office")
- [ ] Switching between saved environment profiles updates the active gain and VAD threshold immediately
- [ ] Calibration data is stored locally only and is not transmitted to any server

---

**US-036: Manage AI Provider API Keys Securely**
As a security-conscious user, I want my API keys to be stored in the system Keychain and never visible in plaintext after entry, so that my credentials are protected if someone else accesses my computer.

**Acceptance Criteria:**
- [ ] API keys entered in Settings > AI Editing > Providers are stored in the macOS Keychain using the app's Keychain access group
- [ ] After initial entry and save, the API key field displays only a masked value (e.g., `sk-...•••••••••••••••••`)
- [ ] A "Show/Hide" toggle reveals the full key only while held, not persistently
- [ ] The key is never written to UserDefaults, any `.plist` file, or any log file
- [ ] Clicking "Verify Key" makes a minimal test API call using the stored key and reports success with the provider's account identifier, or failure with the specific error
- [ ] Deleting a provider configuration removes its API key from the Keychain

---

## Epic 5: Cross-Platform

---

**US-037: Dictate on iPhone Using the Same Configuration**
As a professional who switches between Mac and iPhone throughout the day, I want to open Murmur on my iPhone and have all my settings, snippets, and personal dictionary already synced, so that I can dictate with the same experience on both devices.

**Acceptance Criteria:**
- [ ] Installing Murmur on iPhone and signing into the same iCloud account automatically syncs the personal dictionary, snippet library, style presets, and app profiles from macOS within 60 seconds (on good network)
- [ ] Dictation on iOS uses the same AI provider configuration (API keys synced via CloudKit encrypted fields)
- [ ] Hold-to-dictate on iOS is activated by holding the app's dictation button; no hardware key binding is required on iOS
- [ ] The iOS app presents the same Notes library as the macOS app with identical folder structure and content
- [ ] Changes made to settings on iPhone are reflected on Mac within 60 seconds of the iPhone being connected to the network

---

**US-038: Access and Edit Notes on iOS**
As a mobile user, I want to read and edit my notes from my iPhone, so that I can review and update my dictated notes when I am away from my Mac.

**Acceptance Criteria:**
- [ ] All notes synced via CloudKit appear in the iOS app's notes library within 60 seconds of being created on macOS
- [ ] The iOS note editor supports the same Markdown editing and live preview capabilities as macOS (bold, italic, headings, lists, code blocks, checklists, links)
- [ ] Notes edited on iOS sync back to macOS within 60 seconds
- [ ] Conflict resolution: if the same note is edited on two devices while offline, the app presents both versions and lets the user merge or choose one
- [ ] The iOS app supports full-text search with the same filter options as macOS
- [ ] Images attached to notes on macOS are viewable on iOS (downloaded on demand to conserve storage)

---

**US-039: Use Handoff Between Mac and iPhone**
As a user who starts composing on iPhone and finishes on Mac, I want Handoff to let me continue my note or session on the other device, so that I can move seamlessly between devices mid-task.

**Acceptance Criteria:**
- [ ] When a note is open in the iOS app, a Murmur Handoff activity is advertised via NSUserActivity
- [ ] On the Mac, the Murmur Handoff icon appears in the Dock and the note can be opened with a single click
- [ ] The note opens on the Mac at the same scroll position and selection as on iOS
- [ ] Handoff works in both directions (Mac → iOS and iOS → Mac)
- [ ] Handoff requires both devices to be signed into the same iCloud account and have Bluetooth and Wi-Fi enabled
- [ ] Handoff is not required for sync; disabling Handoff in System Settings does not affect iCloud note sync

---

**US-040: Use Dictation in iOS Keyboard Extension**
As an iOS user, I want to activate Murmur dictation from within any app's keyboard, so that I can dictate into any text field on my iPhone without switching apps.

**Acceptance Criteria:**
- [ ] A Murmur keyboard extension is available and can be enabled in iOS Settings > Keyboard
- [ ] The keyboard extension includes a dictation button that starts a dictation session when tapped and held
- [ ] Dictated text is injected into the host app's text field upon session completion
- [ ] The keyboard extension uses the same AI editing pipeline, personal dictionary, and snippets as the main app (via shared App Group container)
- [ ] The extension activates within 500 ms of tapping the dictation button
- [ ] If the AI provider is unavailable (no network, no Apple Intelligence), the raw transcription is injected without AI editing, with a brief notification in the extension UI

---

**US-041: Sync Notes and Settings Across Devices Using iCloud**
As a user with multiple Apple devices, I want all my notes and settings to sync automatically via iCloud, so that my data is always up to date on every device without any manual export or transfer.

**Acceptance Criteria:**
- [ ] Notes are synced via CloudKit in the app's private CloudKit database; no third-party server is involved
- [ ] New notes created on any device appear on all other signed-in devices within 60 seconds on a good network connection
- [ ] Note edits sync incrementally (not full-note replacement) to minimize bandwidth usage
- [ ] Settings (personal dictionary, snippets, style presets, app profiles, provider configurations) are synced via CloudKit encrypted records; API keys use CloudKit encrypted field storage
- [ ] The sync status (Up to Date / Syncing / Error) is displayed in Settings > iCloud Sync
- [ ] If iCloud is unavailable, the app operates fully offline; all data is stored locally and queued for sync when connectivity is restored
- [ ] A "Force Sync Now" button in Settings > iCloud Sync triggers an immediate full sync

---

# Section 6: Architecture & System Design

## 6.1 High-Level Architecture

Murmur is structured as a layered system with clear separation between audio capture, processing, persistence, and presentation. The two primary process boundaries are the main application process and the menu bar helper process, which communicate via XPC.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              PROJECT V — SYSTEM OVERVIEW                        │
└─────────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────────────┐
  │   Menu Bar App   │     │   Main App (macOS │     │     iOS App              │
  │  (Helper Agent)  │     │   / iPadOS)       │     │  (Compact dictation UI)  │
  │                  │     │                   │     │                          │
  │  ┌────────────┐  │     │  ┌─────────────┐  │     │  ┌────────────────────┐  │
  │  │ Status Bar │  │     │  │ Notes List  │  │     │  │  Dictation HUD     │  │
  │  │   Icon     │  │     │  │    View     │  │     │  │  (floating widget) │  │
  │  └────────────┘  │     │  └─────────────┘  │     │  └────────────────────┘  │
  │  ┌────────────┐  │     │  ┌─────────────┐  │     │  ┌────────────────────┐  │
  │  │ Dictation  │  │     │  │  Note Edit  │  │     │  │   Notes Browser    │  │
  │  │    HUD     │  │     │  │    View     │  │     │  └────────────────────┘  │
  │  └────────────┘  │     │  └─────────────┘  │     └──────────┬───────────────┘
  │  ┌────────────┐  │     │  ┌─────────────┐  │                │
  │  │  Quick     │  │     │  │  Settings   │  │                │
  │  │  Capture   │  │     │  │    Panel    │  │                │
  │  └────────────┘  │     │  └─────────────┘  │                │
  └────────┬─────────┘     └────────┬──────────┘                │
           │    XPC (named pipe)    │                            │
           └────────────┬───────────┘                            │
                        │                                        │
┌───────────────────────▼────────────────────────────────────────▼───────────────┐
│                            CORE SERVICES LAYER                                  │
│                                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────────────┐ │
│  │  Speech Engine   │  │   AI Pipeline    │  │      Note Store               │ │
│  │                  │  │                  │  │                               │ │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌───────────────────────────┐ │ │
│  │ │SpeechAnalyzer│ │  │ │  Provider    │ │  │ │      SwiftData            │ │ │
│  │ │  (macOS 26+) │ │  │ │  Registry   │ │  │ │  (Note/Folder/Tag/etc.)   │ │ │
│  │ └──────────────┘ │  │ └──────────────┘ │  │ └───────────────────────────┘ │ │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌───────────────────────────┐ │ │
│  │ │     VAD      │ │  │ │  Fallback    │ │  │ │    Full-Text Search       │ │ │
│  │ │   (Energy/   │ │  │ │   Chain     │ │  │ │  (FTS5 + Spotlight)  │ │ │
│  │ │  ML-based)   │ │  │ └──────────────┘ │  │ └───────────────────────────┘ │ │
│  │ └──────────────┘ │  │ ┌──────────────┐ │  └───────────────────────────────┘ │
│  │ ┌──────────────┐ │  │ │  Response    │ │                                     │
│  │ │  Microphone  │ │  │ │   Cache     │ │  ┌───────────────────────────────┐   │
│  │ │  Manager     │ │  │ └──────────────┘ │  │      Sync Engine              │   │
│  │ └──────────────┘ │  └──────────────────┘  │                               │   │
│  └──────────────────┘                        │ ┌───────────────────────────┐ │   │
│                                              │ │  CloudKit Container       │ │   │
│  ┌──────────────────┐  ┌──────────────────┐  │ └───────────────────────────┘ │   │
│  │  Text Injection  │  │ Personalization  │  │ ┌───────────────────────────┐ │   │
│  │     Layer        │  │     Layer        │  │ │  Conflict Resolution      │ │   │
│  │                  │  │                  │  │ └───────────────────────────┘ │   │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌───────────────────────────┐ │   │
│  │ │ AXUIElement  │ │  │ │  Dictionary  │ │  │ │  Offline Queue            │ │   │
│  │ │   Bridge     │ │  │ │   Engine     │ │  │ └───────────────────────────┘ │   │
│  │ └──────────────┘ │  │ └──────────────┘ │  └───────────────────────────────┘   │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │                                     │
│  │ │  Clipboard   │ │  │ │   Snippet    │ │                                     │
│  │ │   Fallback   │ │  │ │   Engine     │ │                                     │
│  │ └──────────────┘ │  │ └──────────────┘ │                                     │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │                                     │
│  │ │ App Context  │ │  │ │  App Profile │ │                                     │
│  │ │  Detector    │ │  │ │  Manager     │ │                                     │
│  │ └──────────────┘ │  │ └──────────────┘ │                                     │
│  └──────────────────┘  └──────────────────┘                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           EXTERNAL SERVICES (OPTIONAL)                          │
│                                                                                 │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │  OpenAI API    │  │ Anthropic API  │  │  Ollama (local) │  │  Apple Intl │  │
│  │  (GPT-4o etc.) │  │  (Claude etc.) │  │   HTTP server   │  │  (on-device)│  │
│  └────────────────┘  └────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                            PLATFORM SERVICES                                    │
│                                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  ┌────────────────────┐ │
│  │  CloudKit   │  │  iCloud Drive│  │  Keychain      │  │  Accessibility API │ │
│  │  (CKRecord) │  │  (backups)   │  │  (API keys)    │  │  (AXUIElement)     │ │
│  └─────────────┘  └──────────────┘  └────────────────┘  └────────────────────┘ │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐                         │
│  │  AVFoundation│  │SpeechAnalyzer│  │  Spotlight     │                         │
│  │  (audio I/O)│  │ (transcription│  │  (CSSearchable │                         │
│  │             │  │  macOS 26+)  │  │   Item)        │                         │
│  └─────────────┘  └──────────────┘  └────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6.2 Component Breakdown

### 1. Speech Engine Layer

The Speech Engine Layer owns all audio capture, voice activity detection, and transcription. It wraps Apple's `SpeechAnalyzer` (macOS 26+) and exposes a platform-agnostic protocol upward so that the AI Pipeline and UI layers are fully decoupled from the underlying recognition engine.

**SpeechAnalyzer Wrapper**

The wrapper manages the full lifecycle of a `SpeechAnalyzer` session: authorization, session configuration, audio buffer routing, result streaming, and session teardown. On macOS 26, `SpeechAnalyzer` supports real-time on-device transcription with word-level timing, confidence scores, and language identification. The wrapper converts the native `SpeechAnalyzer` result stream into a platform-neutral `TranscriptionResult` type.

Key responsibilities:
- Requesting and caching `SFSpeechRecognizer`/`SpeechAnalyzer` authorization on first run
- Creating and configuring `SpeechAnalyzerSession` with the appropriate locale and task hint
- Forwarding `AVAudioPCMBuffer` chunks from the Microphone Manager into the session
- Emitting partial (in-progress) and final transcription events as `AsyncStream<TranscriptionEvent>`
- Detecting session interruption (phone call, Siri activation) and emitting pause/resume events
- Applying custom vocabulary from the Dictionary Engine to the recognition request

**Voice Activity Detection (VAD)**

VAD determines whether audio frames contain speech, enabling automatic start/stop of recording and preventing silent segments from being transcribed. The implementation uses a two-tier approach:

- *Primary (ML-based)*: `SpeechAnalyzer` includes built-in voice activity detection as part of its analysis pipeline. When available, the wrapper defers to this signal.
- *Fallback (Energy-based)*: A ring-buffer energy estimator computes the short-time average energy over 30ms frames. Speech detection triggers when energy exceeds a configurable threshold (default: −35 dBFS) for at least two consecutive frames. Silence triggers when energy stays below threshold for a configurable hold duration (default: 1.5 seconds).

The VAD emits a `VoiceActivityState` stream (`.speech`, `.silence`, `.uncertain`) consumed by the Dictation Session Controller to decide when to commit a transcription segment.

**Microphone Manager**

The Microphone Manager owns `AVAudioEngine` and all audio session configuration. Responsibilities:
- Enumerating available input devices and tracking the user's selected device preference
- Configuring `AVAudioSession` for dictation (category: `.record`, mode: `.measurement` on iOS; AVAudioEngine directly on macOS)
- Installing an `AVAudioEngine` tap at the hardware sample rate (typically 44.1 kHz or 48 kHz) and resampling to 16 kHz mono (required by `SpeechAnalyzer`)
- Managing `inputGain` for whisper mode normalization (see below)
- Routing audio to both the VAD and the SpeechAnalyzer wrapper simultaneously via a fan-out buffer adapter
- Handling `AVAudioEngineConfigurationChange` notifications to restart the tap on device change
- Pausing/resuming the tap based on system interruption events

**Whisper Mode Gain Normalization**

When the user speaks below a configurable amplitude threshold (whisper detection), the Microphone Manager applies dynamic gain to normalize the signal before it reaches the recognizer. A simple automatic gain control (AGC) algorithm tracks the 200ms RMS level and applies gain up to a maximum of +24 dB to bring whispered speech into the recognizer's effective range. Gain changes are smoothed with a 50ms attack / 200ms release envelope to avoid artifacts.

---

### 2. AI Pipeline Layer

The AI Pipeline Layer receives raw transcription text and, optionally, transforms it via a cloud or local AI provider. Its output is polished text ready for injection or note storage.

**Provider Protocol and Registry**

All AI backends conform to the `AIProvider` protocol (defined fully in Section 8.1). The `AIProviderRegistry` is a singleton that holds references to all registered provider instances, manages their configuration state, and routes requests to the correct provider based on the user's active selection and the fallback chain.

**Request/Response Flow**

1. The Dictation Session Controller or Note Editor submits an `AIEditRequest` containing the raw transcription, the requested edit style (punctuate, clean, rewrite, summarize, etc.), and contextual metadata (active app, selected tone preset).
2. The Pipeline validates the request and checks the response cache (keyed on a hash of the input text + style parameters). A cache hit returns immediately without a network call.
3. On a cache miss, the request is dispatched to the active provider via `AIProvider.process(_:)`.
4. The pipeline streams the response tokens back to the caller as an `AsyncThrowingStream<String, Error>`. Each token is appended to the live preview in the dictation HUD.
5. On completion, the full response is stored in the cache with a 24-hour TTL.
6. If the active provider throws, the fallback chain is invoked (see below).

**Fallback Chain**

The fallback chain is an ordered list of provider identifiers configured by the user. If provider N fails with a retriable error (rate limit, network timeout, 5xx), the pipeline attempts provider N+1 after a brief backoff. Non-retriable errors (invalid API key, content policy violation) propagate immediately without fallback. The default chain is: `[Apple Intelligence → Ollama (if running) → OpenAI → Anthropic]`, prioritizing privacy by trying local options first.

**Caching**

The response cache is an in-memory `NSCache` with a 50-entry limit backed by a disk cache using `FileManager` in the app's Caches directory. Cache entries are keyed by the SHA-256 hash of `(inputText + styleID + providerID)`. Cache entries are invalidated when the user changes their style preset or provider configuration.

**Rate Limiting**

Per-provider rate limit state is tracked as a token bucket (capacity: provider's stated RPM, refill rate: 1 token/second). When the bucket is empty, requests are queued in a per-provider `AsyncChannel` with a maximum depth of 10. Requests beyond depth 10 are dropped with an `.rateLimitExceeded` error surfaced to the user via a non-blocking notification.

---

### 3. Note Store Layer

The Note Store Layer provides the authoritative local persistence layer for all user data. It is built on SwiftData and exposes a protocol-based interface so that tests can inject a mock store.

**SwiftData Models**

All nine core entities are `@Model`-annotated classes (full definitions in Section 7.2). The `ModelContainer` is configured once at app launch with a persistent store URL in the app's Application Support directory. A separate in-memory container is used for SwiftUI previews and unit tests.

**CRUD Operations**

The `NoteStoreService` wraps `ModelContext` and exposes async methods for all CRUD operations. Write operations are performed on a dedicated background `ModelContext` to avoid blocking the main actor. Saves are debounced with a 500ms timer to batch rapid edits (e.g., live dictation into a note) into single commits.

**Full-Text Search**

Two complementary search mechanisms are maintained in parallel:

- *SQLite FTS5*: A FTS5 virtual table is maintained alongside the main SwiftData store. Notes are indexed by `id`, `title`, and `bodyMarkdown` (with Markdown syntax stripped during indexing). The index is updated incrementally on each note save via a background `IndexUpdateActor`. Queries execute on a background thread using FTS5's built-in ranking (`bm25()`) and return ranked `[UUID]` result sets that are subsequently fetched from SwiftData. FTS5 works identically on macOS and iOS, eliminating the need for platform-specific search implementations. SearchKit (`SKIndex`) was considered but rejected because it is a Carbon-era API unavailable on iOS.
- *Spotlight*: Each note is also donated to Spotlight as a `CSSearchableItem` so users can find notes via system search. The `SpotlightIndexer` actor manages attribution and handles `NSUserActivity` continuations when the user taps a Spotlight result to open the app.

**Folder/Tag Management**

Folders are a self-referential tree (each `Folder` has an optional `parent` relationship). The store layer provides tree traversal methods (`ancestors(of:)`, `descendants(of:)`, `move(_:to:)`) that maintain the `path` denormalized field for efficient prefix queries. Tag operations are straightforward many-to-many joins, with color and sort order stored on the `Tag` model.

---

### 4. Sync Engine Layer

The Sync Engine Layer is responsible for bidirectional synchronization between the local SwiftData store and CloudKit. It operates entirely in the background and presents a `SyncStatus` observable to the UI layer.

**CKSyncEngine Integration**

The app uses Apple's `CKSyncEngine` (available macOS 14+/iOS 17+, well within the macOS 26+ minimum) as the sync coordinator. `CKSyncEngine` manages the full sync lifecycle: change token tracking, pending operation queues, retry logic, and network monitoring. This eliminates the need for a custom `SyncOperationQueue` model or manual `CKFetchRecordZoneChangesOperation` management.

The app implements the `CKSyncEngineDelegate` protocol to:
- Provide records to save and record IDs to delete via `nextRecordZoneChangeBatch()`
- Handle incoming remote changes via `handleEvent(.fetchedRecordZoneChanges)`
- Process conflicts via `handleEvent(.sentRecordZoneChanges)` when `CKSyncEngine` reports `.serverRecordChanged` errors

All user data lives in a single custom zone named `ProjectVZone` within the app's private CloudKit database.

**Conflict Resolution**

The conflict resolution strategy is "last-writer-wins" at the field level, not the record level. Each syncable field on each entity carries a `lastModifiedDate`. When `CKSyncEngine` reports a `.serverRecordChanged` conflict, the delegate fetches the server record and performs field-level merge: for each field, the version with the later `lastModifiedDate` wins. For the note body (`bodyMarkdown`) specifically, if both the local and remote versions have been modified since the last common ancestor, the engine creates a conflict copy (a new Note with a `conflictOf` relationship pointer) and presents a non-blocking in-app notification prompting the user to review and resolve (see Section 9.8 for the conflict resolution UI).

**Offline Behavior**

`CKSyncEngine` automatically queues pending changes when offline and drains them when connectivity resumes. The engine's state (including pending changes and change tokens) is persisted automatically by `CKSyncEngine.State.Serialization`, which the app stores in the Application Support directory. A full resync can be triggered manually via the Settings panel (clears the stored state and re-fetches all records).

---

### 5. Text Injection Layer

The Text Injection Layer delivers dictated text into third-party applications. It is macOS-only (the system-wide injection feature does not apply to iOS, where dictation targets the app's own text fields).

**Accessibility API Bridge**

The bridge uses `AXUIElement` to locate the focused text field in the frontmost application and inject text directly via `AXUIElementSetAttributeValue(kAXValueAttribute)` for simple text fields, or via the Accessibility Actions API (`AXUIElementPerformAction(kAXPressAction)` on synthetic keystroke events) for rich text editors. The implementation:

1. Calls `AXUIElementCreateSystemWide()` and reads `kAXFocusedUIElementAttribute` to identify the target element.
2. Reads `kAXValueAttribute` and `kAXSelectedTextRangeAttribute` to determine the current selection.
3. Replaces the selection (or inserts at cursor) with the dictated text.
4. Fires a synthesized `kAXValueChangedNotification` so the target app processes the change correctly.

For apps that use non-standard text controls (Electron-based apps, some Java apps), a character-by-character `CGEvent` keystroke sequence is used as the secondary strategy. This is slower but universally compatible.

**Clipboard Fallback**

If the Accessibility API call fails (permission not granted, or the target element is not AX-accessible), the engine falls back to:
1. Saving the current clipboard contents.
2. Writing the dictated text to the clipboard.
3. Synthesizing a Cmd+V paste keystroke via `CGEvent`.
4. After a 200ms delay, restoring the original clipboard contents.

This fallback is transparent to the user but does briefly displace clipboard contents. The user is informed about this behavior during onboarding and can disable clipboard fallback entirely in Settings.

**App Context Detector**

The App Context Detector monitors `NSWorkspace.didActivateApplicationNotification` to track the frontmost application. For each app, it:
- Records the bundle identifier
- Looks up the matching `AppProfile` from the Personalization Layer
- Notifies the Speech Engine Layer of any profile-specific settings (language, VAD sensitivity, snippet set)
- Determines the appropriate injection strategy (AX direct, keystroke simulation, or clipboard)

**Cursor Management**

After injection, the engine verifies that the cursor has advanced by the expected character count by re-reading `kAXSelectedTextRangeAttribute`. If the cursor position is unexpected, it emits a `.injectionVerificationFailed` event, which triggers a retry with the clipboard fallback strategy.

**Undo Support**

After successful injection, the engine stores the injected text range (`startIndex`, `length`, `targetAppBundleID`) in a `LastInjection` struct. This enables the "Undo Last Dictation" HUD button (visible for 5 seconds post-injection):

- For **clipboard fallback** injections (Cmd+V paste): the target app's native undo (Cmd+Z) handles this automatically; no additional mechanism needed
- For **AX API** injections: the undo button reads the current `kAXValueAttribute` from the target text field, selects the injected range via `kAXSelectedTextRangeAttribute`, and deletes it. If the text field has been modified since injection (cursor moved, text edited), undo is disabled to avoid deleting the wrong content

**Injection Failure Recovery**

If injection fails after all retry attempts (AX + clipboard fallback), the engine:
1. Saves the dictated text as a new note tagged `#failed-injection` with the target app name in metadata
2. Posts a persistent notification: "Dictation couldn't be inserted into [app name]. Your text has been saved." with a "Copy to Clipboard" action
3. The `DictationSession` record is always created regardless of injection outcome — dictated text is NEVER silently lost

---

### 6. UI Layer

**SwiftUI Views**

All views are implemented in SwiftUI and organized into three targets: `ProjectV` (main app), `ProjectVMenuBar` (menu bar helper), and `ProjectVWidgets` (iOS/iPadOS widget extension). Shared view components live in a `ProjectVUI` Swift package.

**Menu Bar Component**

The menu bar component runs as a `LSUIElement` helper app (no Dock icon, no main window). It presents an `NSStatusItem` with a waveform icon that animates during active dictation. The popover contains: a one-tap record button, the last 3 dictation results, a quick-capture text field for note creation, and shortcuts to open the main app and settings.

**XPC Protocol (Menu Bar Helper ↔ Main App)**

The menu bar helper communicates with the main app exclusively via XPC (not named pipes). `SpeechAnalyzer` runs in the **main app process** because it requires access to the SwiftData store, AI pipeline, and CloudKit sync engine. The helper captures audio via `AVAudioEngine` and forwards buffers to the main app.

```swift
@objc protocol MurmurXPCProtocol {
    // Helper → Main App
    func startDictation(language: String?, mode: String) async throws
    func stopDictation() async throws
    func sendAudioBuffer(_ bufferData: Data, timestamp: Double) async throws
    func cancelDictation() async throws

    // Main App → Helper (via reply/callback)
    func transcriptionUpdate(_ text: String, isFinal: Bool) async
    func dictationStateChanged(_ state: String) async  // idle, recording, processing, error
    func injectionResult(success: Bool, errorMessage: String?) async
}
```

**Lifecycle behavior:**
- When the helper starts and the main app is not running, the helper launches the main app in the background (no visible window) via `NSWorkspace.shared.open(_:configuration:)` with `activates = false`
- If the main app crashes during a dictation session, the helper preserves the partial audio buffer to a temporary file in the shared App Group container; the main app processes it on next launch
- The XPC connection is established lazily on first dictation and kept alive while the helper is running; reconnection is automatic on failure

**Main Window**

The main window is a standard `NSWindow`/`UIWindow` containing:
- A sidebar with folder tree and tag list
- A note list for the selected folder/tag context
- A note editor (Markdown editor with live preview; see Section 4.4.4)
- An inspector panel (note metadata, folder/tag assignment, dictation session history)

**Dictation HUD**

The Dictation HUD is a floating, non-activating `NSPanel` (macOS) or a sheet/overlay (iOS). It displays:
- Animated waveform visualization (powered by the Microphone Manager's amplitude stream)
- Live transcription text (streaming partial results)
- AI processing indicator (spinner) while cloud editing is in progress
- The final text preview with a 3-second dismiss timer
- Cancel and Commit buttons

**Settings**

Settings are implemented using the native `Settings` scene on macOS (rendered as a multi-tab `NSTabView`) and a `NavigationStack` form on iOS. Tabs: General, Dictation, AI Providers, Appearance, Shortcuts, Privacy, Advanced.

---

### 7. Personalization Layer

**Dictionary Engine**

The Dictionary Engine maintains the user's custom `DictionaryEntry` records and applies them at two points: (1) before recognition, by injecting custom words into the `SpeechAnalyzer` custom vocabulary API, and (2) after recognition, by running a post-processing string substitution pass that replaces phonetic approximations with the canonical spellings defined in the user's dictionary.

**Snippet Engine**

The Snippet Engine monitors transcription output for trigger phrases. After each finalized transcription segment, the engine runs a trie-based substring search over the text. Matches are expanded in-place before the text is dispatched to the injection or note-save pathway. Variable substitution (e.g., `{date}`, `{time}`, `{clipboard}`) is resolved at expansion time.

**App Profile Manager**

The App Profile Manager loads the `AppProfile` for the currently active application (matched by bundle ID) and applies its overrides to the Speech Engine and AI Pipeline. Overrides include: dictation language, VAD sensitivity, AI style preset, injection strategy preference, and which snippet sets are active. A default "catch-all" profile applies when no specific profile matches.

---

## 6.3 Hybrid Processing Flow

### Decision Logic: On-Device vs. Cloud AI

```
Transcription complete?
        │
        ▼
  AI Editing enabled in settings?
  ├── NO  ──────────────────────────────────────────► inject/save raw text
  └── YES
        │
        ▼
  Active AI provider = Apple Intelligence?
  ├── YES ─► On-device Foundation Model request ────► inject/save
  └── NO
        │
        ▼
  Ollama running locally (health check < 200ms)?
  ├── YES ─► Local HTTP request to Ollama ──────────► inject/save
  └── NO
        │
        ▼
  Network available + user allows cloud?
  ├── NO  ──────────────────────────────────────────► inject/save raw text
  │                                             (notify: no AI available)
  └── YES
        │
        ▼
  Dispatch to configured cloud provider
  (OpenAI / Anthropic / custom endpoint)
        │
        ▼
  Response received?
  ├── YES ─► inject/save AI-edited text
  └── NO (error/timeout)
        │
        ├── Retriable? ─► attempt next provider in fallback chain
        └── Fatal?     ─► inject/save raw text + surface error notification
```

### Full Dictation Lifecycle Sequence Diagram

```
User          MenuBar/HUD     MicManager    SpeechEngine    VAD          AI Pipeline    TextInjection    NoteStore
 │                │               │               │           │               │               │               │
 │──press hotkey──►               │               │           │               │               │               │
 │                │──startSession─►               │           │               │               │               │
 │                │               │──startTap()───►           │               │               │               │
 │                │               │               │           │               │               │               │
 │──(speaks)──────────────────────►               │           │               │               │               │
 │                │               │──audioBuffer──►           │               │               │               │
 │                │               │──audioBuffer──────────────►               │               │               │
 │                │               │               │──energy───►               │               │               │
 │                │               │               │           │──VAD:speech───►               │               │
 │                │               │──audioBuffer──►           │               │               │               │
 │                │               │  (continuous) │           │               │               │               │
 │                │◄──partialResult────────────────│           │               │               │               │
 │                │  (live update)│               │           │               │               │               │
 │                │               │               │           │               │               │               │
 │──(stops speaking)──────────────►               │           │               │               │               │
 │                │               │──audioBuffer──────────────►               │               │               │
 │                │               │               │──energy───►               │               │               │
 │                │               │               │           │──VAD:silence──►               │               │
 │                │               │──[hold 1.5s]──►           │               │               │               │
 │                │               │──stopTap()────►           │               │               │               │
 │                │               │               │──finalizeSession()         │               │               │
 │                │               │               │──finalResult──────────────►               │               │
 │                │               │               │           │               │               │               │
 │                │               │               │  (Dictionary post-process) │               │               │
 │                │               │               │  (Snippet expansion)       │               │               │
 │                │               │               │           │               │               │               │
 │                │               │               │           │──AIEditRequest─►               │               │
 │                │◄──showSpinner──────────────────────────────────────────────│               │               │
 │                │               │               │           │  (stream tokens►               │               │
 │                │◄──livePreview──────────────────────────────────────────────│               │               │
 │                │               │               │           │──finalResponse─►               │               │
 │                │               │               │           │               │               │               │
 │                │               │               │           │  [mode = inject?]              │               │
 │                │               │               │           │               │──injectText()──►               │
 │                │               │               │           │               │  AX attempt   │               │
 │                │               │               │           │               │  success?──YES►(done)          │
 │                │               │               │           │               │  NO           │               │
 │                │               │               │           │               │──clipboardFB──►               │
 │                │               │               │           │               │               │               │
 │                │               │               │           │  [mode = note?]                               │
 │                │               │               │           │               │               │──createNote()──►
 │                │               │               │           │               │               │  (SwiftData)  │
 │                │               │               │           │               │               │──indexNote()──►
 │                │               │               │           │               │               │  (FTS5)       │
 │                │               │               │           │               │               │──donateSpotlight►
 │                │◄──dismissHUD───────────────────────────────────────────────────────────────────────────────│
 │                │               │               │           │               │               │               │
```

---

## 6.4 Pluggable AI Backend Architecture

### Swift Protocol Definition

The complete `AIProvider` protocol is defined in Section 8.1. At the architecture level, providers are structured as follows:

```
AIProvider (protocol)
    │
    ├── OpenAIProvider       (implements streaming via Server-Sent Events)
    ├── AnthropicProvider    (implements streaming via Anthropic SSE API)
    ├── OllamaProvider       (implements streaming via Ollama /api/generate)
    └── AppleIntelligenceProvider  (implements via Foundation Models framework)
```

### Provider Lifecycle

```
Registration:
  App launch ──► AIProviderRegistry.register(OpenAIProvider())
              ──► AIProviderRegistry.register(AnthropicProvider())
              ──► AIProviderRegistry.register(OllamaProvider())
              ──► AIProviderRegistry.register(AppleIntelligenceProvider())

Configuration:
  User opens Settings ► AI Providers tab
  ► Selects provider ► enters API key / endpoint
  ► AIProviderRegistry.configure(providerID:, config:)
  ► config stored in Keychain (API keys) + UserDefaults (endpoint, model)

Health Check (runs on config save + every 5 min while app is active):
  AIProviderRegistry.checkHealth(providerID:)
  ► provider.healthCheck() async throws → HealthStatus
  ► status: .available | .degraded(latencyMs) | .unavailable(reason)
  ► result published to ProviderStatusView in Settings

Request:
  AIEditRequest ──► pipeline validates ──► cache check
  ──► registry.activeProvider.process(request) async throws
  ──► AsyncThrowingStream<String, Error> returned
  ──► tokens streamed to HUD / editor

Teardown:
  App will terminate ──► registry.teardownAll()
  ──► each provider cancels in-flight requests
  ──► response cache flushed to disk
```

### Adding a New Provider (Contributor Guide)

To add a new AI provider:
1. Create a new Swift file in `Sources/ProjectVCore/AI/Providers/`.
2. Implement the `AIProvider` protocol (all required methods; see Section 8.1).
3. Define a `static let providerID: ProviderID` with a stable reverse-DNS string (e.g., `"com.projectv.provider.myservice"`).
4. Implement `makeConfigurationView() -> some View` returning a SwiftUI form for the provider's settings.
5. Register the provider in `AIProviderRegistry.registerBuiltins()` in `AppDelegate` / `@main`.
6. Add a test target that conforms to `AIProviderTestSuite` (a shared XCTest protocol in the test utilities package) to validate the provider against the contract.
7. Add the provider's name and configuration schema to `providerManifest.json` (used by the Settings UI to auto-generate documentation links).

### Error Handling and Fallback Chain

```swift
// Pseudocode for fallback chain execution

func processWithFallback(_ request: AIEditRequest) async throws -> AsyncThrowingStream<String, Error> {
    let chain = registry.fallbackChain  // [ProviderID], user-configured order

    for providerID in chain {
        guard let provider = registry.provider(for: providerID),
              provider.status == .available || provider.status.isDegraded else {
            continue
        }
        do {
            return try await provider.process(request)
        } catch AIProviderError.rateLimited(let retryAfter) {
            // skip to next; record retry-after for this provider
            rateLimitState[providerID] = retryAfter
            continue
        } catch AIProviderError.networkUnavailable {
            continue
        } catch AIProviderError.invalidAPIKey, AIProviderError.contentPolicyViolation {
            throw  // non-retriable; propagate immediately
        } catch {
            continue  // unknown error: try next in chain
        }
    }
    // all providers exhausted; return raw transcription
    throw AIProviderError.allProvidersExhausted
}
```

---

## 6.5 Data Flow Diagrams

### Dictation Flow

```
[Microphone Hardware]
        │  PCM audio (hardware sample rate)
        ▼
[AVAudioEngine Tap]
        │  resample → 16kHz mono PCM
        ├──────────────────────────────────────────────────────────┐
        ▼                                                          ▼
[VAD (energy/ML)]                                    [SpeechAnalyzer Session]
        │                                                          │
  .speech / .silence                               partial + final TranscriptionResult
        │                                                          │
        └──────────────────────┬───────────────────────────────────┘
                               ▼
                   [DictationSessionController]
                     - tracks start/end times
                     - collects partial results
                     - triggers segment commit on VAD silence
                               │
                               ▼
                     [Dictionary Post-Processor]
                     - phonetic → canonical substitution
                               │
                               ▼
                     [Snippet Engine]
                     - trigger phrase expansion
                     - variable substitution
                               │
                       ┌───────┴──────────┐
                       ▼                  ▼
              [AI Pipeline]         [Direct Path]
           (if AI editing on)     (if AI editing off)
                       │                  │
                       └───────┬──────────┘
                               ▼
                    ┌──────────┴──────────┐
                    ▼                     ▼
           [Text Injection]         [Note Creation]
        (frontmost app AX)        (NoteStoreService)
```

### Note Creation Flow

```
[Dictated Text / Manual Input]
        │
        ▼
[NoteStoreService.createNote(title:body:)]
        │
        ├──► SwiftData ModelContext.insert(note)
        │
        ├──► FolderService.assign(note, to: selectedFolder)
        │         └── updates note.folder relationship
        │             updates folder.noteCount (denormalized)
        │
        ├──► TagService.apply(tags, to: note)
        │         └── updates note.tags many-to-many join
        │
        ├──► ModelContext.save()   ◄── debounced 500ms
        │
        ├──► FTS5Indexer.index(note)   ◄── background actor
        │         └── INSERT INTO note_fts
        │
        ├──► SpotlightIndexer.donate(note)
        │         └── CSSearchableItemAttributeSet
        │             CSIndexExtension update
        │
        └──► SyncEngine.enqueue(.create, record: note.ckRecord)
                  └── appended to SyncOperationQueue (SwiftData)
                      NWPathMonitor triggers drain if online
```

### Sync Flow

```
[Local Write / Update / Delete]
        │
        ▼
[SyncOperationQueue.enqueue(op)]   ◄── persisted to SwiftData
        │
[NWPathMonitor: online?]
  ├── NO  ──► queue waits; retries on next connectivity event
  └── YES
        │
        ▼
[SyncEngine.drain()]
        │
        ▼
[CKModifyRecordsOperation]
  records to save:   [CKRecord] (from pending .create / .update ops)
  records to delete: [CKRecordID] (from pending .delete ops)
        │
        ├── success
        │       ├── update serverChangeToken (UserDefaults/iCloud KV)
        │       ├── mark SyncOperations as .completed
        │       └── remove completed ops from queue
        │
        └── partialFailure / conflict
                ├── .serverRecordChanged error
                │       └── fetch server record
                │           run field-level merge
                │           re-attempt save
                │           if note body conflict ──► create conflict copy
                │
                └── .networkFailure / .serviceUnavailable
                        └── exponential backoff (1s, 2s, 4s, max 60s)
                            re-enqueue failed ops

[Incoming changes from other devices]
        │
[CKDatabaseSubscription / silent push]
        │
        ▼
[CKFetchRecordZoneChangesOperation (delta from stored changeToken)]
        │
        ▼
[merge into local SwiftData context]
  - new records  ──► insert
  - changed records ──► field-level merge
  - deleted records ──► delete local copy (move to trash if note)
        │
        ▼
[notify UI via @Query / SwiftData observation]
```

### Search Flow

```
[User types query in search field]
        │
        ▼
[SearchDebouncer: 150ms delay]
        │
        ▼
[SearchService.query(text:filters:)]
        │
        ├──────────────────────────────────────────────────────┐
        ▼                                                      ▼
[SQLite FTS5: bm25() ranked]                    [SwiftData predicate filter]
  - full-text ranked results                      - tag filter
  - returns [UUID] ranked by relevance            - folder filter
        │                                         - date range filter
        └──────────────────────┬───────────────────────────────┘
                               ▼
                    [Result Set Intersection]
                    (FTS5 UUIDs ∩ SwiftData UUIDs)
                               │
                               ▼
                    [Fetch full Note objects]
                    (SwiftData fetch by UUID set)
                               │
                               ▼
                    [SearchResultViewModel]
                    - highlighted snippets (FTS5 snippet())
                    - sort: relevance / date / title
                               │
                               ▼
                    [SearchResultsView (SwiftUI)]
                    - updates via @State binding
                    - infinite scroll with pagination
```

---

# Section 7: Data Model & Schema

## 7.1 Core Entities

### Note

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key, generated on creation |
| `title` | `String` | User-visible title, max 500 chars |
| `bodyMarkdown` | `String` | Note body stored as CommonMark Markdown source text |
| `createdAt` | `Date` | Set once on creation, never modified |
| `updatedAt` | `Date` | Updated on every save |
| `isPinned` | `Bool` | Pinned notes appear at top of list |
| `isTrashed` | `Bool` | Soft-delete flag |
| `trashedAt` | `Date?` | Set when `isTrashed` becomes true |
| `wordCount` | `Int` | Cached count, updated on save |
| `characterCount` | `Int` | Cached count, updated on save |
| `sourceApp` | `String?` | Bundle ID of app active during dictation |
| `language` | `String?` | BCP-47 language tag of transcription locale |
| `ckChangeTag` | `String?` | CloudKit `recordChangeTag` for conflict detection |
| `ckSyncedAt` | `Date?` | Last successful sync timestamp |

Relationships:
- `folder: Folder?` — many-to-one (nullable; nil = inbox/unfiled)
- `tags: [Tag]` — many-to-many
- `dictationSession: DictationSession?` — one-to-one (optional)
- `conflictOf: Note?` — self-referential (points to the original if this is a conflict copy)

Indexes: `updatedAt DESC` (default list sort), `createdAt DESC`, `isTrashed`, `isPinned`, `folder.id`, `sourceApp`

Constraints: `title` must be non-empty after trimming whitespace; `wordCount >= 0`; `updatedAt >= createdAt`

---

### Folder

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `name` | `String` | Display name, max 255 chars |
| `icon` | `String?` | SF Symbol name |
| `colorHex` | `String?` | Hex color string for folder accent |
| `sortOrder` | `Int` | Position among siblings |
| `path` | `String` | Denormalized ancestor path: `/uuid1/uuid2/uuid3` |
| `depth` | `Int` | Nesting depth (0 = top-level) |
| `createdAt` | `Date` | Creation timestamp |
| `updatedAt` | `Date` | Last modification timestamp |

Relationships:
- `parent: Folder?` — self-referential many-to-one
- `children: [Folder]` — self-referential one-to-many (cascade delete)
- `notes: [Note]` — one-to-many (nullify on delete: notes move to inbox)

Indexes: `parent.id`, `path` (prefix queries for subtree fetch), `sortOrder`

Constraints: `name` unique within the same parent; `depth <= 20` (prevents runaway recursion); `path` must start with `/` and be consistent with the parent chain

---

### Tag

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `name` | `String` | Display name, max 100 chars |
| `colorHex` | `String` | Hex color string (default: system blue) |
| `sortOrder` | `Int` | Position in tag list |
| `createdAt` | `Date` | Creation timestamp |
| `usageCount` | `Int` | Cached count of associated notes |

Relationships:
- `notes: [Note]` — many-to-many

Indexes: `name` (unique, case-insensitive), `sortOrder`

Constraints: `name` must be unique (case-insensitive); `colorHex` must be a valid 6-digit hex

---

### Snippet

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `trigger` | `String` | The phrase that activates expansion |
| `expansion` | `String` | The text to expand to |
| `label` | `String?` | Human-readable name for the snippet |
| `variables` | `[String: String]` | Variable definitions (name → description) |
| `isCaseSensitive` | `Bool` | Whether trigger matching is case-sensitive |
| `isEnabled` | `Bool` | Global on/off switch |
| `usageCount` | `Int` | How many times the snippet has fired |
| `lastUsedAt` | `Date?` | Timestamp of last expansion |
| `createdAt` | `Date` | Creation timestamp |

Relationships:
- `appProfiles: [AppProfile]` — many-to-many (snippet is scoped to specific profiles; empty = global)

Indexes: `trigger` (for trie construction), `isEnabled`, `lastUsedAt DESC`

Constraints: `trigger` must be non-empty; `expansion` must be non-empty; `trigger` must be unique across all enabled snippets (warn but allow disabled duplicates)

---

### DictionaryEntry

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `canonicalForm` | `String` | The correct spelling/form |
| `phoneticForm` | `String?` | Phonetic approximation the recognizer might produce |
| `alternativeForms` | `[String]` | Other recognized forms that should map to canonical |
| `isSuppressed` | `Bool` | If true, suppress this word from recognition output |
| `language` | `String?` | BCP-47 tag; nil = applies to all languages |
| `createdAt` | `Date` | Creation timestamp |

Indexes: `canonicalForm`, `phoneticForm`, `language`

Constraints: `canonicalForm` must be non-empty; at least one of `phoneticForm` or `alternativeForms` must be non-empty if this is a substitution rule (not just a vocabulary addition)

---

### StylePreset

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `name` | `String` | Display name |
| `systemPromptTemplate` | `String` | The prompt template with `{input}` placeholder |
| `isBuiltIn` | `Bool` | Built-in presets cannot be deleted |
| `sortOrder` | `Int` | Position in preset list |
| `createdAt` | `Date` | Creation timestamp |
| `updatedAt` | `Date` | Last modification timestamp |

Indexes: `isBuiltIn`, `sortOrder`

Constraints: `systemPromptTemplate` must contain `{input}`; `name` must be unique

---

### AIProviderConfig

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `providerID` | `String` | Stable reverse-DNS provider identifier |
| `displayName` | `String` | User-editable display name |
| `endpointURL` | `String?` | Custom endpoint (for Ollama / self-hosted) |
| `modelIdentifier` | `String` | Model name/ID (e.g., `gpt-4o`, `claude-opus-4`) |
| `isEnabled` | `Bool` | Whether this configuration is active |
| `fallbackOrder` | `Int` | Position in fallback chain |
| `maxTokens` | `Int` | Request token limit |
| `temperature` | `Double` | Sampling temperature (0.0–2.0) |
| `createdAt` | `Date` | Creation timestamp |
| `updatedAt` | `Date` | Last modification timestamp |

Note: API keys are NOT stored in SwiftData. They are stored in the macOS/iOS Keychain, keyed by `"projectv.apikey.\(providerID)"`.

Relationships: none (standalone configuration record)

Indexes: `providerID` (unique), `isEnabled`, `fallbackOrder`

---

### AppProfile

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `bundleIdentifier` | `String?` | Target app bundle ID; nil = default/catch-all profile |
| `displayName` | `String` | User-given name for the profile |
| `language` | `String?` | BCP-47 override; nil = use system default |
| `vadSensitivity` | `Double` | VAD threshold override (0.0–1.0); nil = global default |
| `injectionStrategy` | `String` | `"accessibility"`, `"keystroke"`, `"clipboard"`, `"auto"` |
| `aiEnabled` | `Bool?` | Override AI editing for this app; nil = use global |
| `stylePresetID` | `UUID?` | Default style preset for this app |
| `isEnabled` | `Bool` | Whether this profile is active |
| `createdAt` | `Date` | Creation timestamp |
| `updatedAt` | `Date` | Last modification timestamp |

Relationships:
- `snippets: [Snippet]` — many-to-many (snippets active in this profile)

Indexes: `bundleIdentifier` (unique among non-nil values), `isEnabled`

---

### DictationSession

| Property | Type | Description |
|---|---|---|
| `id` | `UUID` | Primary key |
| `startedAt` | `Date` | Session start timestamp |
| `endedAt` | `Date?` | Session end timestamp (nil if interrupted) |
| `durationSeconds` | `Double` | Audio duration in seconds |
| `wordCount` | `Int` | Words in final transcription |
| `characterCount` | `Int` | Characters in final transcription |
| `rawTranscription` | `String` | Pre-AI-editing transcription |
| `finalTranscription` | `String` | Post-AI-editing transcription (may equal raw) |
| `language` | `String` | BCP-47 language tag |
| `sourceAppBundleID` | `String?` | Bundle ID of frontmost app during session |
| `aiProviderID` | `String?` | Which AI provider processed this session |
| `aiLatencyMs` | `Int?` | AI processing time in milliseconds |
| `injectionSucceeded` | `Bool?` | Whether text injection succeeded |
| `createdAt` | `Date` | Record creation timestamp |

Relationships:
- `note: Note?` — one-to-one (if session was saved to a note)

Indexes: `startedAt DESC`, `sourceAppBundleID`, `language`

---

## 7.2 SwiftData Schema

```swift
import SwiftData
import Foundation

// MARK: - Note

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var bodyMarkdown: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isTrashed: Bool
    var trashedAt: Date?
    var wordCount: Int
    var characterCount: Int
    var sourceApp: String?
    var language: String?
    var ckChangeTag: String?
    var ckSyncedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Folder.notes)
    var folder: Folder?

    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag]

    @Relationship(deleteRule: .cascade, inverse: \DictationSession.note)
    var dictationSession: DictationSession?

    @Relationship(deleteRule: .nullify)
    var conflictOf: Note?

    init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String = "",
        folder: Folder? = nil,
        tags: [Tag] = []
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.folder = folder
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.isTrashed = false
        self.wordCount = 0
        self.characterCount = 0
    }
}

// MARK: - Folder

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String?
    var colorHex: String?
    var sortOrder: Int
    var path: String
    var depth: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Folder.children)
    var parent: Folder?

    @Relationship(deleteRule: .cascade)
    var children: [Folder]

    @Relationship(deleteRule: .nullify)
    var notes: [Note]

    init(
        id: UUID = UUID(),
        name: String,
        parent: Folder? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.parent = parent
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.path = parent.map { "\($0.path)\(id.uuidString)/" } ?? "/\(id.uuidString)/"
        self.depth = (parent?.depth ?? -1) + 1
        self.children = []
        self.notes = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Tag

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var usageCount: Int

    @Relationship(deleteRule: .nullify, inverse: \Note.tags)
    var notes: [Note]

    init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF", sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.usageCount = 0
        self.notes = []
    }
}

// MARK: - Snippet

@Model
final class Snippet {
    @Attribute(.unique) var id: UUID
    var trigger: String
    var expansion: String
    var label: String?
    @Attribute(.transformable(by: "DictionaryTransformer")) var variables: [String: String]
    var isCaseSensitive: Bool
    var isEnabled: Bool
    var usageCount: Int
    var lastUsedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \AppProfile.snippets)
    var appProfiles: [AppProfile]

    init(
        id: UUID = UUID(),
        trigger: String,
        expansion: String,
        label: String? = nil,
        isCaseSensitive: Bool = false
    ) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.label = label
        self.variables = [:]
        self.isCaseSensitive = isCaseSensitive
        self.isEnabled = true
        self.usageCount = 0
        self.createdAt = Date()
        self.appProfiles = []
    }
}

// MARK: - DictionaryEntry

@Model
final class DictionaryEntry {
    @Attribute(.unique) var id: UUID
    var canonicalForm: String
    var phoneticForm: String?
    @Attribute(.transformable(by: "StringArrayTransformer")) var alternativeForms: [String]
    var isSuppressed: Bool
    var language: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        canonicalForm: String,
        phoneticForm: String? = nil,
        alternativeForms: [String] = [],
        isSuppressed: Bool = false,
        language: String? = nil
    ) {
        self.id = id
        self.canonicalForm = canonicalForm
        self.phoneticForm = phoneticForm
        self.alternativeForms = alternativeForms
        self.isSuppressed = isSuppressed
        self.language = language
        self.createdAt = Date()
    }
}

// MARK: - StylePreset

@Model
final class StylePreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPromptTemplate: String
    var isBuiltIn: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        systemPromptTemplate: String,
        isBuiltIn: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.systemPromptTemplate = systemPromptTemplate
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AIProviderConfig

@Model
final class AIProviderConfig {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var providerID: String
    var displayName: String
    var endpointURL: String?
    var modelIdentifier: String
    var isEnabled: Bool
    var fallbackOrder: Int
    var maxTokens: Int
    var temperature: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        providerID: String,
        displayName: String,
        modelIdentifier: String,
        endpointURL: String? = nil,
        fallbackOrder: Int = 99
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.endpointURL = endpointURL
        self.modelIdentifier = modelIdentifier
        self.isEnabled = false
        self.fallbackOrder = fallbackOrder
        self.maxTokens = 2048
        self.temperature = 0.3
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AppProfile

@Model
final class AppProfile {
    @Attribute(.unique) var id: UUID
    var bundleIdentifier: String?
    var displayName: String
    var language: String?
    var vadSensitivity: Double?
    var injectionStrategy: String
    var aiEnabled: Bool?
    var stylePresetID: UUID?
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Snippet.appProfiles)
    var snippets: [Snippet]

    init(
        id: UUID = UUID(),
        displayName: String,
        bundleIdentifier: String? = nil,
        injectionStrategy: String = "auto"
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.injectionStrategy = injectionStrategy
        self.isEnabled = true
        self.snippets = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - DictationSession

@Model
final class DictationSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Double
    var wordCount: Int
    var characterCount: Int
    var rawTranscription: String
    var finalTranscription: String
    var language: String
    var sourceAppBundleID: String?
    var aiProviderID: String?
    var aiLatencyMs: Int?
    var injectionSucceeded: Bool?
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var note: Note?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        rawTranscription: String = "",
        language: String = "en-US"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.rawTranscription = rawTranscription
        self.finalTranscription = rawTranscription
        self.language = language
        self.durationSeconds = 0
        self.wordCount = 0
        self.characterCount = 0
        self.createdAt = Date()
    }
}
```

### Migration Strategy

SwiftData migrations are handled via versioned `VersionedSchema` types. The initial release ships as `ProjectVSchemaV1`. When breaking schema changes are required in future versions:

1. Define `ProjectVSchemaV2` with updated `@Model` definitions.
2. Implement a `SchemaMigrationPlan` conforming type specifying the migration stage from V1 to V2.
3. For lightweight migrations (adding optional properties, adding indexes): use `.lightweight` migration stage. SwiftData handles these automatically.
4. For heavyweight migrations (renaming properties, changing relationship cardinality, splitting/merging models): implement a custom `MigrationStage.custom` with explicit `willMigrate` and `didMigrate` closures.
5. The `ModelContainer` is configured with the migration plan at launch:

```swift
let container = try ModelContainer(
    for: Note.self, Folder.self, Tag.self, Snippet.self,
         DictionaryEntry.self, StylePreset.self, AIProviderConfig.self,
         AppProfile.self, DictationSession.self,
    migrationPlan: ProjectVMigrationPlan.self
)
```

All schema version numbers are persisted in the store metadata and checked at launch. A migration failure that cannot be resolved automatically presents a recovery prompt offering to reset the local store (data is recoverable from CloudKit sync).

---

## 7.3 CloudKit Record Types

### Record Zone Strategy

All user data lives in a single custom zone named `ProjectVZone` within the app's private CloudKit database. Using a custom zone provides:
- Atomic multi-record saves
- Efficient delta sync via zone-level change tokens
- Zone-level delete (useful for account reset)

Shared notes (future feature) will use a dedicated `ProjectVSharedZone` in the shared database, with `CKShare` records linking to originals.

### CKRecord Type Mappings

| Entity | CKRecord Type | Syncable Fields | Local-Only Fields |
|---|---|---|---|
| Note | `ProjectV_Note` | id, title, bodyMarkdown, createdAt, updatedAt, isPinned, isTrashed, trashedAt, wordCount, language, folderID (ref), tagIDs (list) | ckChangeTag, ckSyncedAt, sourceApp, dictationSessionID |
| Folder | `ProjectV_Folder` | id, name, icon, colorHex, sortOrder, path, depth, parentID (ref), createdAt, updatedAt | — |
| Tag | `ProjectV_Tag` | id, name, colorHex, sortOrder, createdAt | usageCount |
| Snippet | `ProjectV_Snippet` | id, trigger, expansion, label, variables (JSON), isCaseSensitive, isEnabled, createdAt | usageCount, lastUsedAt |
| DictionaryEntry | `ProjectV_DictionaryEntry` | all fields | — |
| StylePreset | `ProjectV_StylePreset` | id, name, systemPromptTemplate, isBuiltIn, sortOrder, createdAt, updatedAt | — |
| AIProviderConfig | `ProjectV_AIProviderConfig` | id, providerID, displayName, endpointURL, modelIdentifier, isEnabled, fallbackOrder, maxTokens, temperature | — |
| AppProfile | `ProjectV_AppProfile` | id, bundleIdentifier, displayName, language, vadSensitivity, injectionStrategy, aiEnabled, stylePresetID, isEnabled | — |
| DictationSession | `ProjectV_DictationSession` | id, startedAt, endedAt, durationSeconds, wordCount, rawTranscription, finalTranscription, language | sourceAppBundleID, aiProviderID, aiLatencyMs, injectionSucceeded |

Note: `AIProviderConfig` syncs configuration but NOT API keys. API keys remain in the local Keychain and are never written to CloudKit records.

### Field Encoding Details

- `bodyMarkdown`: Stored as a `String` CKRecord field. For notes exceeding CloudKit's 1 MB string field limit, the body is written to a temporary file and stored as a `CKAsset`.
- `variables` (Snippet): JSON-encoded `[String: String]` stored as a `String` field.
- `tagIDs` (Note): Stored as `[CKRecord.Reference]` list, each referencing a `ProjectV_Tag` record.
- `folderID` (Note): Single `CKRecord.Reference` with `.deleteSelf` action (if folder is deleted, note's folderID reference becomes dangling, which the sync engine interprets as "move to inbox").

### CKSyncEngine Integration

Sync is managed by `CKSyncEngine` (macOS 14+/iOS 17+), which handles change token management, pending operation queues, retry logic, push notification subscriptions, and network monitoring internally. The app implements `CKSyncEngineDelegate`:

```swift
final class SyncCoordinator: CKSyncEngineDelegate {

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
        switch event {
        case .stateUpdate(let stateUpdate):
            // Persist CKSyncEngine.State.Serialization to disk
            persistState(stateUpdate.stateSerialization)

        case .fetchedRecordZoneChanges(let changes):
            // Apply incoming remote changes to local SwiftData store
            for modification in changes.modifications {
                applyRemoteRecord(modification.record)
            }
            for deletion in changes.deletions {
                applyRemoteDeletion(deletion.recordID)
            }

        case .sentRecordZoneChanges(let sentChanges):
            // Handle conflicts: .serverRecordChanged triggers field-level merge
            for failedSave in sentChanges.failedRecordSaves {
                if case .serverRecordChanged = failedSave.value.code {
                    resolveConflict(local: failedSave.value.record,
                                    server: failedSave.value.serverRecord)
                }
            }

        case .accountChange(let event):
            handleAccountChange(event)

        default: break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // Return pending local changes from SwiftData
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges
        return await buildBatch(from: pendingChanges)
    }
}
```

State serialization (`CKSyncEngine.State.Serialization`) is persisted to the app's Application Support directory, ensuring sync state survives app restarts. A full resync can be triggered manually via Settings by clearing the persisted state.

---

## 7.4 Full-Text Search Index

### SQLite FTS5 Index

A SQLite FTS5 virtual table is maintained alongside the main SwiftData store. FTS5 was chosen over SearchKit (`SKIndex`) because SearchKit is a Carbon-era API unavailable on iOS — FTS5 works identically on both platforms and is actively maintained as part of SQLite.

The FTS5 virtual table is created as:

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
    title,
    body,
    content='',        -- contentless table; source data lives in SwiftData
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2'
);
```

Notes are indexed by `title` and `bodyMarkdown` (with Markdown syntax stripped during indexing via a lightweight Markdown-to-plaintext conversion). The `unicode61` tokenizer with diacritics removal ensures accent-insensitive search across all supported languages.

Queries use FTS5's built-in `bm25()` ranking function for relevance scoring and `snippet()` for generating highlighted excerpts in search results.

### Spotlight Integration

Each note is also donated to Spotlight as a `CSSearchableItem`:

```swift
let attributes = CSSearchableItemAttributeSet(contentType: .text)
attributes.title = note.title
attributes.contentDescription = String(note.bodyMarkdown.strippingMarkdown().prefix(300))
attributes.keywords = note.tags.map(\.name)
attributes.contentCreationDate = note.createdAt
attributes.contentModificationDate = note.updatedAt

let item = CSSearchableItem(
    uniqueIdentifier: "projectv-note-\(note.id.uuidString)",
    domainIdentifier: "com.projectv.notes",
    attributeSet: attributes
)
CSSearchableIndex.default().indexSearchableItems([item])
```

The app registers a `NSUserActivityTypes` entry for `com.projectv.openNote` so that tapping a Spotlight result deep-links directly to the note.

### Index Update Strategy

Updates are handled by a dedicated `IndexUpdateActor` (a Swift actor to serialize index access):

- **Real-time (foreground edits)**: After each debounced SwiftData save (500ms), the changed note is submitted to the actor's update queue. The actor executes FTS5 `INSERT` or `UPDATE` statements to index the note's title and stripped body text.
- **Batched (background)**: A `BGProcessingTask` registered as `com.projectv.indexRebuild` runs when the device is idle and connected to power. It performs a full `INSERT INTO note_fts(note_fts) VALUES('rebuild')` to reindex any notes whose content has drifted from the index.
- **Deletion**: When a note is hard-deleted (purged from trash), the actor deletes the corresponding FTS5 row and calls `CSSearchableIndex.default().deleteSearchableItems(withIdentifiers:)`.
- **Trash behavior**: Trashed notes are removed from the Spotlight donation immediately but remain in the FTS5 index (filtered out at query time via a JOIN with the main note table's `isTrashed` flag) so that a future "search trash" feature can include them.

---

# Section 8: API & Interface Contracts

## 8.1 AI Provider Protocol

```swift
import Foundation

// MARK: - Core Types

/// A stable, reverse-DNS string identifying a provider implementation.
/// Example: "com.projectv.provider.openai"
public typealias ProviderID = String

/// The category of AI operation being requested.
public enum AIEditMode: String, Codable, Sendable {
    case punctuateAndCapitalize  // add punctuation, fix capitalization
    case cleanUp                 // light grammar and filler word removal
    case rewrite                 // paraphrase while preserving meaning
    case summarize               // condense to key points
    case expand                  // elaborate on the content
    case translate               // translate to target language
    case custom                  // use a raw system prompt from StylePreset
}

/// A fully-specified request to the AI pipeline.
public struct AIEditRequest: Sendable {
    /// The raw input text to process.
    public let inputText: String
    /// The requested transformation.
    public let mode: AIEditMode
    /// For `.custom` mode: the full system prompt template with `{input}` replaced.
    public let customSystemPrompt: String?
    /// BCP-47 target language for translation mode.
    public let targetLanguage: String?
    /// Contextual hint: the bundle ID of the app receiving the output.
    public let sourceAppBundleID: String?
    /// Maximum tokens to generate.
    public let maxTokens: Int
    /// Sampling temperature (0.0–2.0).
    public let temperature: Double

    public init(
        inputText: String,
        mode: AIEditMode,
        customSystemPrompt: String? = nil,
        targetLanguage: String? = nil,
        sourceAppBundleID: String? = nil,
        maxTokens: Int = 2048,
        temperature: Double = 0.3
    ) {
        self.inputText = inputText
        self.mode = mode
        self.customSystemPrompt = customSystemPrompt
        self.targetLanguage = targetLanguage
        self.sourceAppBundleID = sourceAppBundleID
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

/// The result of a completed AI edit operation.
public struct AIEditResponse: Sendable {
    /// The final edited text.
    public let outputText: String
    /// Input tokens consumed (if reported by the provider).
    public let inputTokensUsed: Int?
    /// Output tokens generated (if reported by the provider).
    public let outputTokensUsed: Int?
    /// Wall-clock latency in milliseconds.
    public let latencyMs: Int
    /// Identifier of the model that produced this response.
    public let modelIdentifier: String
}

/// Health status reported by a provider's health check.
public enum ProviderHealthStatus: Sendable {
    case available
    case degraded(latencyMs: Int)
    case unavailable(reason: String)
}

/// Errors that an AI provider may throw.
public enum AIProviderError: Error, Sendable {
    case invalidAPIKey
    case rateLimited(retryAfterSeconds: Int?)
    case networkUnavailable
    case requestTooLong(tokenCount: Int, limit: Int)
    case contentPolicyViolation(detail: String?)
    case providerNotConfigured
    case streamInterrupted(partialOutput: String)
    case unknownError(underlying: Error)
    case allProvidersExhausted
}

// MARK: - Provider Configuration

/// The persisted configuration for a provider instance.
/// API keys are not included here; they are read from the Keychain.
public struct AIProviderConfiguration: Sendable {
    public let providerID: ProviderID
    public let endpointURL: URL?
    public let modelIdentifier: String
    public let maxTokens: Int
    public let temperature: Double
}

// MARK: - AI Provider Protocol

/// The core protocol that all AI backend implementations must conform to.
///
/// Implementations are expected to be actors or use internal synchronization
/// to ensure safe concurrent access from multiple callers.
public protocol AIProvider: Sendable {

    // MARK: Identity

    /// A stable reverse-DNS identifier for this provider. Must not change between versions.
    static var providerID: ProviderID { get }

    /// Human-readable display name shown in Settings.
    var displayName: String { get }

    /// SF Symbol name for the provider's icon.
    var iconName: String { get }

    // MARK: Lifecycle

    /// Called by the registry after the provider is registered.
    /// Implementations should validate stored configuration and initialize
    /// any internal state. Must not make network calls.
    func prepare(configuration: AIProviderConfiguration) async throws

    /// Perform a lightweight connectivity/authentication check.
    /// Should complete within 5 seconds. Used to populate the health indicator in Settings.
    func healthCheck() async -> ProviderHealthStatus

    /// Called when the app is terminating or the provider is being deregistered.
    /// Implementations must cancel all in-flight requests.
    func teardown() async

    // MARK: Core Processing

    /// Process an edit request and stream the response tokens.
    ///
    /// - Parameter request: The fully-specified edit request.
    /// - Returns: An `AsyncThrowingStream` that yields string fragments as they
    ///   are received from the model. The stream completes normally when the
    ///   response is fully received, or terminates with an `AIProviderError` on failure.
    func process(_ request: AIEditRequest) async throws -> AsyncThrowingStream<String, Error>

    /// Process an edit request and return the complete response (non-streaming).
    ///
    /// Providers may implement this by accumulating the stream, or by using
    /// a separate non-streaming API call. The default implementation accumulates the stream.
    func processComplete(_ request: AIEditRequest) async throws -> AIEditResponse

    // MARK: Configuration UI

    /// Returns a SwiftUI view that renders the provider's configuration form.
    /// Called by the Settings panel when the user selects this provider.
    @MainActor
    func makeConfigurationView() -> AnyView

    // MARK: Capability Declaration

    /// The set of AIEditModes this provider supports.
    /// Modes not included here will be disabled in the UI when this provider is active.
    var supportedModes: Set<AIEditMode> { get }

    /// Whether this provider supports streaming responses.
    var supportsStreaming: Bool { get }

    /// Whether this provider operates entirely on-device (no network calls).
    var isOnDevice: Bool { get }
}

// MARK: - Default Implementations

public extension AIProvider {

    func processComplete(_ request: AIEditRequest) async throws -> AIEditResponse {
        let start = Date()
        var output = ""
        let stream = try await process(request)
        for try await token in stream {
            output += token
        }
        return AIEditResponse(
            outputText: output,
            inputTokensUsed: nil,
            outputTokensUsed: nil,
            latencyMs: Int(Date().timeIntervalSince(start) * 1000),
            modelIdentifier: "unknown"
        )
    }

    var supportsStreaming: Bool { true }
    var isOnDevice: Bool { false }
}

// MARK: - Provider Registry

/// Central registry for all AI provider instances.
/// Implemented as a Swift actor (not @MainActor) to avoid main-thread contention
/// during dictation-time AI dispatch. UI-facing state is published via the
/// separate AIProviderStatusPublisher observable.
public actor AIProviderRegistry {

    public static let shared = AIProviderRegistry()

    private(set) var registeredProviders: [any AIProvider] = []
    private(set) var fallbackChain: [ProviderID] = []
    private(set) var healthStatuses: [ProviderID: ProviderHealthStatus] = [:]

    public func register(_ provider: some AIProvider) {
        registeredProviders.append(provider)
        statusPublisher.update(providers: registeredProviders, health: healthStatuses, chain: fallbackChain)
    }

    public func provider(for id: ProviderID) -> (any AIProvider)? {
        registeredProviders.first { type(of: $0).providerID == id }
    }

    public func configure(providerID: ProviderID, with configuration: AIProviderConfiguration) async throws {
        guard let provider = provider(for: providerID) else { return }
        try await provider.prepare(configuration: configuration)
    }

    public func updateFallbackChain(_ chain: [ProviderID]) {
        fallbackChain = chain
        statusPublisher.update(providers: registeredProviders, health: healthStatuses, chain: fallbackChain)
    }

    public func updateHealthStatus(_ providerID: ProviderID, status: ProviderHealthStatus) {
        healthStatuses[providerID] = status
        statusPublisher.update(providers: registeredProviders, health: healthStatuses, chain: fallbackChain)
    }

    public func teardownAll() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in registeredProviders {
                group.addTask { await provider.teardown() }
            }
        }
    }

    /// Main-actor-bound publisher for SwiftUI observation.
    nonisolated let statusPublisher = AIProviderStatusPublisher()
}

// MARK: - UI-Facing Observable

/// Publishes AI provider state to SwiftUI views on the main actor.
/// Avoids coupling the registry's actor isolation to UI rendering.
@MainActor
public final class AIProviderStatusPublisher: ObservableObject {
    @Published public private(set) var registeredProviders: [any AIProvider] = []
    @Published public private(set) var fallbackChain: [ProviderID] = []
    @Published public private(set) var healthStatuses: [ProviderID: ProviderHealthStatus] = [:]

    nonisolated func update(providers: [any AIProvider], health: [ProviderID: ProviderHealthStatus], chain: [ProviderID]) {
        Task { @MainActor in
            self.registeredProviders = providers
            self.healthStatuses = health
            self.fallbackChain = chain
        }
    }
}
```

---

## 8.2 Speech Engine Interface

```swift
import Foundation
import AVFoundation

// MARK: - Transcription Types

/// A single word with timing and confidence metadata.
public struct TranscriptionWord: Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float
}

/// A transcription result — may be partial (in-progress) or final (committed).
public struct TranscriptionResult: Sendable {
    public let text: String
    public let words: [TranscriptionWord]
    public let isFinal: Bool
    public let confidence: Float
    public let language: String  // BCP-47
    public let sessionID: UUID
}

/// Events emitted by the speech engine.
public enum TranscriptionEvent: Sendable {
    case partial(TranscriptionResult)
    case final(TranscriptionResult)
    case error(SpeechEngineError)
    case sessionStarted(sessionID: UUID)
    case sessionEnded(sessionID: UUID, duration: TimeInterval)
    case interrupted(reason: InterruptionReason)
    case resumed
}

public enum InterruptionReason: Sendable {
    case phoneCall
    case siriActivation
    case routeChange
    case appBackgrounded
}

/// Voice activity detection state.
public enum VoiceActivityState: Sendable {
    case speech(amplitude: Float)
    case silence
    case uncertain
}

/// Errors from the speech engine.
public enum SpeechEngineError: Error, Sendable {
    case notAuthorized
    case authorizationDenied
    case engineNotAvailable
    case audioSessionFailed(underlying: Error)
    case recognizerUnavailableForLocale(String)
    case sessionExpired
    case unknownError(underlying: Error)
}

// MARK: - Speech Engine Protocol

/// Abstraction over the underlying speech recognition implementation.
/// On macOS 26+, the default implementation wraps `SpeechAnalyzer`.
public protocol SpeechEngineProtocol: AnyObject, Sendable {

    // MARK: Authorization

    /// Request speech recognition authorization from the user.
    /// Resolves immediately if authorization was previously granted or denied.
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// The current authorization status.
    var authorizationStatus: SpeechAuthorizationStatus { get }

    // MARK: Session Management

    /// Begin a new dictation session.
    ///
    /// - Parameters:
    ///   - locale: The BCP-47 locale to use for recognition. Nil uses the device default.
    ///   - customVocabulary: Additional words to inject into the recognizer.
    /// - Returns: A UUID identifying the session, used to correlate transcription events.
    func startSession(locale: Locale?, customVocabulary: [String]) async throws -> UUID

    /// Finalize the current session and flush any buffered audio.
    /// The engine will emit a final `TranscriptionResult` before ending.
    func stopSession() async

    /// Pause audio capture without ending the session (e.g., for system interruption).
    func pauseSession() async

    /// Resume a paused session.
    func resumeSession() async

    // MARK: Output Streams

    /// A live stream of transcription events.
    /// Active while a session is running. Resumes after `resumeSession()`.
    var transcriptionEvents: AsyncStream<TranscriptionEvent> { get }

    /// A live stream of voice activity state, emitted at ~30ms intervals while a session is active.
    var voiceActivityStream: AsyncStream<VoiceActivityState> { get }

    /// A live stream of normalized audio amplitude (0.0–1.0) for waveform visualization.
    var amplitudeStream: AsyncStream<Float> { get }

    // MARK: Configuration

    /// The list of available audio input devices (macOS only; on iOS this is always the built-in mic).
    var availableInputDevices: [AudioInputDevice] { get }

    /// The currently selected input device.
    var selectedInputDevice: AudioInputDevice? { get set }

    /// Whether whisper mode gain normalization is active.
    var isWhisperModeEnabled: Bool { get set }

    /// VAD sensitivity (0.0 = least sensitive, 1.0 = most sensitive).
    var vadSensitivity: Float { get set }
}

/// Authorization status for speech recognition.
public enum SpeechAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// An audio input device (microphone).
public struct AudioInputDevice: Identifiable, Sendable {
    public let id: String            // AVAudioSession port UID or CoreAudio device UID
    public let name: String
    public let isDefault: Bool
    public let isBuiltIn: Bool
}

// MARK: - Speech Engine Delegate (for Objective-C interop / legacy use)

/// Callback-based interface for callers that cannot use async/await.
@objc public protocol SpeechEngineDelegate: AnyObject {
    @objc optional func speechEngine(_ engine: AnyObject, didReceivePartialResult result: String, sessionID: UUID)
    @objc optional func speechEngine(_ engine: AnyObject, didReceiveFinalResult result: String, words: [[String: Any]], sessionID: UUID)
    @objc optional func speechEngineDidStartSession(_ engine: AnyObject, sessionID: UUID)
    @objc optional func speechEngineDidEndSession(_ engine: AnyObject, sessionID: UUID)
    @objc optional func speechEngine(_ engine: AnyObject, didFailWithError error: Error)
}
```

---

## 8.3 Note Store Interface

```swift
import Foundation
import SwiftData

// MARK: - Query Types

/// Sort options for note lists.
public enum NoteSortOrder: Sendable {
    case updatedAtDescending
    case updatedAtAscending
    case createdAtDescending
    case createdAtAscending
    case titleAscending
    case titleDescending
    case wordCountDescending
}

/// A composable filter for note queries.
public struct NoteFilter: Sendable {
    public var folderID: UUID?                 // nil = all folders
    public var includeSubfolders: Bool         // default true
    public var tagIDs: [UUID]                  // AND semantics by default
    public var tagMatchMode: TagMatchMode      // .all (AND) or .any (OR)
    public var includeTrashed: Bool            // default false
    public var pinnedOnly: Bool                // default false
    public var dateRange: DateInterval?        // filter by updatedAt
    public var language: String?               // BCP-47 filter
    public var sourceApp: String?              // bundle ID filter

    public enum TagMatchMode: Sendable { case all, any }

    public static let all = NoteFilter(
        tagIDs: [], tagMatchMode: .all,
        includeTrashed: false, pinnedOnly: false,
        includeSubfolders: true
    )
}

/// A search result with highlighting metadata.
public struct NoteSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let snippet: String        // highlighted excerpt (~150 chars)
    public let relevanceScore: Float
    public let matchedFields: Set<MatchedField>

    public enum MatchedField: Sendable { case title, body, tags }
}

// MARK: - Note Store Protocol

public protocol NoteStoreProtocol: AnyObject, Sendable {

    // MARK: Notes — CRUD

    @discardableResult
    func createNote(
        title: String,
        bodyMarkdown: String,
        folder: Folder?,
        tags: [Tag]
    ) async throws -> Note

    func note(for id: UUID) async throws -> Note?

    func updateNote(
        _ id: UUID,
        title: String?,
        bodyMarkdown: String?,
        isPinned: Bool?
    ) async throws

    func trashNote(_ id: UUID) async throws
    func restoreNote(_ id: UUID) async throws
    func deleteNote(_ id: UUID) async throws   // permanent; removes from trash

    func emptyTrash() async throws

    // MARK: Notes — Querying

    func notes(filter: NoteFilter, sortOrder: NoteSortOrder, limit: Int, offset: Int) async throws -> [Note]

    func noteCount(filter: NoteFilter) async throws -> Int

    func search(query: String, filter: NoteFilter, limit: Int) async throws -> [NoteSearchResult]

    // MARK: Folders — CRUD

    @discardableResult
    func createFolder(name: String, parent: Folder?, icon: String?, colorHex: String?) async throws -> Folder

    func folder(for id: UUID) async throws -> Folder?

    func updateFolder(_ id: UUID, name: String?, icon: String?, colorHex: String?, sortOrder: Int?) async throws

    func moveFolder(_ id: UUID, to newParentID: UUID?) async throws

    func deleteFolder(_ id: UUID, moveNotesTo destinationFolderID: UUID?) async throws

    func folders(parentID: UUID?) async throws -> [Folder]   // nil = top-level

    func ancestors(of folderID: UUID) async throws -> [Folder]

    func descendants(of folderID: UUID) async throws -> [Folder]

    // MARK: Tags — CRUD

    @discardableResult
    func createTag(name: String, colorHex: String) async throws -> Tag

    func allTags() async throws -> [Tag]

    func updateTag(_ id: UUID, name: String?, colorHex: String?) async throws

    func deleteTag(_ id: UUID) async throws

    func applyTags(_ tagIDs: [UUID], to noteID: UUID) async throws

    func removeTags(_ tagIDs: [UUID], from noteID: UUID) async throws

    // MARK: Observation

    /// Subscribe to changes for a specific note.
    /// The stream emits the updated Note whenever it changes, and completes if the note is deleted.
    func noteChanges(for id: UUID) -> AsyncStream<Note?>

    /// Subscribe to folder tree changes.
    func folderTreeChanges() -> AsyncStream<[Folder]>
}

// MARK: - SwiftData Implementation Stub

/// The production implementation backed by SwiftData.
public actor NoteStoreService: NoteStoreProtocol {
    private let container: ModelContainer
    private let backgroundContext: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.backgroundContext = ModelContext(container)
        self.backgroundContext.autosaveEnabled = false
    }

    // Full implementation in NoteStoreService.swift
    // Omitted here for brevity; conforms to all protocol methods above.
}
```

---

## 8.4 Text Injection Interface

```swift
import Foundation
import CoreGraphics

// MARK: - Injection Types

/// The result of a text injection attempt.
public enum InjectionResult: Sendable {
    case success(strategy: InjectionStrategy)
    case failed(error: InjectionError)
    case skipped(reason: SkipReason)

    public enum SkipReason: Sendable {
        case noFocusedTextField
        case userDisabledInjection
        case appOptedOut
    }
}

/// The strategy used to inject text.
public enum InjectionStrategy: String, Sendable {
    case accessibilityDirect    // AXUIElement setValue
    case accessibilityKeystrokes // AX synthesized keystrokes
    case clipboardPaste         // cmd+V fallback
}

/// Errors during injection.
public enum InjectionError: Error, Sendable {
    case accessibilityPermissionDenied
    case noFocusedElement
    case elementNotWritable
    case verificationFailed(expected: Int, actual: Int)
    case clipboardOperationFailed
    case unknownError(underlying: Error)
}

/// Context about the application currently in the foreground.
public struct AppContext: Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let processID: pid_t
    public let preferredInjectionStrategy: InjectionStrategy
    public let supportsAccessibility: Bool
    public let isElectronApp: Bool
    public let isJavaApp: Bool
}

// MARK: - Text Injection Protocol

public protocol TextInjectionProtocol: AnyObject, Sendable {

    // MARK: Context Detection

    /// The application currently in the foreground.
    var currentAppContext: AppContext? { get }

    /// Subscribe to foreground app changes.
    var appContextChanges: AsyncStream<AppContext?> { get }

    /// Probe whether the accessibility API is usable for the given app context.
    func checkAccessibilitySupport(for context: AppContext) async -> Bool

    // MARK: Injection

    /// Inject text into the currently focused text field.
    ///
    /// - Parameters:
    ///   - text: The text to inject.
    ///   - strategy: Preferred strategy. If `.accessibilityDirect` fails, the engine
    ///     automatically tries `.accessibilityKeystrokes`, then `.clipboardPaste`
    ///     (unless `allowFallback` is false).
    ///   - allowFallback: Whether to attempt fallback strategies on failure.
    func inject(
        text: String,
        preferredStrategy: InjectionStrategy,
        allowFallback: Bool
    ) async -> InjectionResult

    /// Replace the current text selection (if any) with the given text.
    func replaceSelection(with text: String) async -> InjectionResult

    /// Append text at the end of the current field's content.
    func appendToField(text: String) async -> InjectionResult

    // MARK: Cursor & Selection

    /// Read the current selected text range (character offset + length).
    func selectedRange() async -> Range<Int>?

    /// Move the cursor to a specific character offset.
    func setCursorPosition(_ offset: Int) async throws

    // MARK: Clipboard

    /// Save and restore clipboard around a paste operation.
    /// - Parameter work: The closure in which clipboard content may be modified.
    func withClipboardPreservation(_ work: () async throws -> Void) async rethrows

    // MARK: Permissions

    /// Returns true if the Accessibility permission has been granted.
    var hasAccessibilityPermission: Bool { get }

    /// Open the Privacy > Accessibility preferences pane.
    func openAccessibilityPreferences()
}
```

---

## 8.5 Shortcuts.app Integration

Murmur registers a `NSExtensionPrincipalClass` for App Intents (using the `AppIntents` framework) and exposes the following actions to Shortcuts.app:

### Dictation Actions

| Action Name | Intent Identifier | Inputs | Output | Description |
|---|---|---|---|---|
| Start Dictation | `StartDictationIntent` | `destinationMode: DictationDestination` (`.inject`, `.newNote`, `.clipboard`) | `DictationSessionEntity` | Begins a dictation session. Resolves when the session ends. |
| Stop Dictation | `StopDictationIntent` | `sessionID: UUID` (optional) | `DictationSessionEntity` | Stops the active session. |
| Transcribe Audio File | `TranscribeAudioFileIntent` | `file: IntentFile`, `language: String?` | `String` | Transcribes an audio file using the on-device engine. |
| Edit Text with AI | `EditTextWithAIIntent` | `text: String`, `mode: AIEditMode`, `provider: AIProviderEntity?` | `String` | Runs a text through the AI pipeline and returns the result. |

### Note Actions

| Action Name | Intent Identifier | Inputs | Output | Description |
|---|---|---|---|---|
| Create Note | `CreateNoteIntent` | `title: String`, `body: String?`, `folder: FolderEntity?`, `tags: [TagEntity]?` | `NoteEntity` | Creates a new note. |
| Append to Note | `AppendToNoteIntent` | `note: NoteEntity`, `text: String` | `NoteEntity` | Appends text to an existing note's body. |
| Find Notes | `FindNotesIntent` | `query: String?`, `folder: FolderEntity?`, `tags: [TagEntity]?`, `limit: Int?` | `[NoteEntity]` | Searches notes and returns matches. |
| Get Note Content | `GetNoteContentIntent` | `note: NoteEntity`, `format: ContentFormat` (`.plain`, `.markdown`) | `String` | Returns the body text of a note. |
| Move Note to Folder | `MoveNoteIntent` | `note: NoteEntity`, `folder: FolderEntity` | `NoteEntity` | Moves a note to a different folder. |
| Trash Note | `TrashNoteIntent` | `note: NoteEntity` | `Bool` | Moves a note to trash. |

### Snippet Actions

| Action Name | Intent Identifier | Inputs | Output | Description |
|---|---|---|---|---|
| Expand Snippet | `ExpandSnippetIntent` | `trigger: String`, `variables: [String: String]?` | `String` | Returns the expanded text for a snippet trigger. |
| Create Snippet | `CreateSnippetIntent` | `trigger: String`, `expansion: String`, `label: String?` | `SnippetEntity` | Creates a new snippet. |

### Example Shortcut Workflows

**"Dictate and Create Note"**: Start Dictation (mode: `.newNote`) → if note created → Apply Tag "Inbox" → Show notification "Note saved"

**"Morning Summary"**: Find Notes (folder: "Daily Notes", query: today's date) → Get Note Content → Edit Text with AI (mode: `.summarize`) → Show result in notification or speak via Text to Speech

**"Voice Memo to Markdown Note"**: Receive audio file from Files → Transcribe Audio File → Edit Text with AI (mode: `.cleanUp`) → Create Note (title: current date + time, body: AI output, folder: "Voice Memos")

---

## 8.6 URL Scheme

Murmur registers the custom URL scheme `projectv://` via its `Info.plist` `CFBundleURLTypes` entry.

### Scheme Overview

```
projectv://<action>[/<resource-id>][?<parameters>]
```

### Supported URL Patterns

#### Navigation

| URL Pattern | Description | Parameters |
|---|---|---|
| `projectv://` | Open the main app window | — |
| `projectv://notes` | Open the notes list (inbox) | `sort=updated\|created\|title` |
| `projectv://note/<uuid>` | Open a specific note by ID | `edit=true` to open in edit mode |
| `projectv://folder/<uuid>` | Open a folder | — |
| `projectv://tag/<name>` | Open notes filtered by tag name | — |
| `projectv://search?q=<query>` | Open search with a pre-filled query | `q` (required), `folder=<uuid>` (optional) |
| `projectv://settings` | Open the Settings window | `tab=general\|dictation\|ai\|privacy` |
| `projectv://settings/ai-providers` | Open AI provider settings | — |

#### Actions

| URL Pattern | Description | Parameters |
|---|---|---|
| `projectv://new-note` | Create a new note | `title=<text>`, `body=<text>`, `folder=<uuid>`, `tags=<comma-separated-names>` |
| `projectv://dictate` | Start a dictation session | `mode=inject\|note\|clipboard`, `language=<bcp47>` |
| `projectv://dictate/stop` | Stop the active dictation session | — |
| `projectv://import` | Import a text file as a note | `url=<file-url>` (must be a security-scoped URL from Shortcuts/Files) |

#### x-callback-url Support

Murmur supports the `x-callback-url` specification for inter-app communication:

```
projectv://x-callback-url/new-note
    ?title=<text>
    &body=<text>
    &x-success=<callback-url>
    &x-cancel=<cancel-url>
    &x-error=<error-url>
```

On success, the callback URL is opened with the following appended parameters:
- `noteID=<uuid>` — the UUID of the newly created note
- `title=<encoded-text>` — the title of the created note

On error, the error URL is opened with:
- `errorCode=<string>` — machine-readable error code (e.g., `validation_failed`, `storage_error`)
- `errorMessage=<encoded-text>` — human-readable description

### URL Handling Implementation Notes

- All URL handling is centralized in `URLRouter`, an `ObservableObject` that responds to `onOpenURL` in the SwiftUI `App` struct and `application(_:open:options:)` in `AppDelegate`.
- UUIDs in URL paths are validated before use. Invalid UUIDs return an error to the caller (via x-callback-url if present) without crashing.
- The `projectv://dictate` action requires that the app is in the foreground or is a menu bar helper; if the app is suspended, the action is queued and executed on the next foreground activation.
- URL parameters are percent-decoded using `URLComponents`. Multi-value parameters (e.g., `tags`) are comma-separated and individually percent-decoded.

---

# Section 9: UI/UX Specifications

## 9.1 Menu Bar Component

### Icon States

The menu bar icon communicates application state at a glance using a minimal waveform/microphone glyph rendered as a template image so macOS applies the correct tint for light/dark menu bars automatically.

| State | Icon Description | Badge/Animation |
|---|---|---|
| Idle | Static microphone outline | None |
| Listening | Microphone with animated radiating arcs | Pulsing animation (respects Reduce Motion) |
| Processing | Microphone with spinning arc segment | Rotation animation |
| Error | Microphone with exclamation badge | Static red badge dot |
| Muted/Paused | Microphone with diagonal strike-through | None |

All icon states are implemented as SF Symbols variants where possible, with custom symbol fallbacks for states not covered by system symbols. The icon uses `NSStatusItem` with a template image so it correctly inverts in dark and light menu bars.

### Popover Layout

The popover is presented via `NSPopover` attached to the status item, sized to approximately 340 × 480 points. It contains five logical zones stacked vertically:

1. **Header Row** — App name/logo left-aligned, gear icon (Settings) right-aligned
2. **Dictation Toggle** — Large pill-shaped toggle button: "Start Dictating" / "Stop Dictating" with current mode indicator (Append / Replace / Command)
3. **Recent Notes Strip** — Horizontally scrolling list of the 5 most recently edited notes, showing title and relative timestamp
4. **Search Field** — Single-line search bar that filters notes library inline; pressing Return opens the main window with results
5. **Footer** — Keyboard shortcut reminder, "Open Notes Library" button

```
┌──────────────────────────────────────────┐
│  Murmur                          ⚙️   │
├──────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────────┐  │
│  │   🎙  Start Dictating              │  │
│  │        Mode: Append                │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Recent Notes                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │Meeting   │ │Draft:    │ │Shopping  │ │
│  │Notes     │ │Blog Post │ │List      │ │
│  │2m ago    │ │1h ago    │ │Yesterday │ │
│  └──────────┘ └──────────┘ └──────────┘ │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ 🔍 Search notes...                 │  │
│  └────────────────────────────────────┘  │
│                                          │
├──────────────────────────────────────────┤
│  ⌘⇧Space to dictate  [Open Notes Library]│
└──────────────────────────────────────────┘
```

### Keyboard Shortcut

The global hotkey to open/close the popover defaults to `⌘⇧Space`. This is user-configurable in Settings > General. The shortcut is registered via `CGEventTap` or, where permitted, the Accessibility API, and activates regardless of which application is frontmost.

---

## 9.2 Main Window Layout

The main window is a standard macOS document-style window using `NavigationSplitView` with three columns: Sidebar, Note List, and Editor. All split dividers are draggable; column widths are persisted in `UserDefaults`.

**Sidebar (leading column, default 220 pt wide):**
- Section: **Smart Folders** — All Notes, Untagged, Today, Dictated Today
- Section: **Folders** — User-created folder tree with disclosure triangles; supports drag-and-drop reordering and nesting up to 3 levels deep
- Section: **Tags** — Tag browser listing all tags alphabetically with note count badge; clicking a tag filters the note list
- **Search bar** pinned to sidebar top; searches title + body + tags

**Note List (center column, default 280 pt wide):**
- Toggle between table view (single-row with title + snippet + date) and grid view (card tiles with truncated preview)
- Sort options: Date Modified, Date Created, Title A–Z
- Multi-select enabled for bulk operations (delete, move, export, tag)
- New Note button pinned at top

**Editor Pane (trailing column, fills remaining width):**
- Formatting toolbar: Bold, Italic, Underline, Strikethrough | Heading styles (H1–H3, Body) | Bulleted list, Numbered list, Checklist | Code block | Inline code
- Title field above body (separate focus stops)
- Tag chip row below title, with inline tag autocomplete
- Word count / character count in footer bar
- Dictation indicator badge in toolbar when session is active for this note

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Murmur                                               🔴 🟡 🟢          │
├───────────────────┬──────────────────────┬──────────────────────────────────┤
│ 🔍 Search notes   │ [Table] [Grid]  + New │ B  I  U  ~~  | H1 H2 H3 ¶      │
├───────────────────┤                      │ •  1. ☑  </>  | 🎙 Dictating    │
│ ▼ SMART FOLDERS   │ ● Meeting Notes      ├──────────────────────────────────┤
│   All Notes  142  │   Budget review...   │                                  │
│   Today        3  │   Today, 2:14 PM     │  Meeting Notes — Q2 Budget       │
│   Dictated     3  │                      │  ──────────────────────────────  │
│   Untagged    18  │ ● Draft: Blog Post   │  #work  #finance  + add tag      │
│                   │   Swift concurrency  │                                  │
│ ▼ FOLDERS         │   Today, 1:05 PM     │  The Q2 budget review covered    │
│   📁 Work    (47) │                      │  headcount projections through   │
│   📁 Personal(31) │ ● Shopping List      │  fiscal year end. Key decisions: │
│     📁 Health (8) │   Milk, eggs, bread  │                                  │
│   📁 Archive (64) │   Yesterday          │  - Headcount: freeze at current  │
│                   │                      │    levels through Q3             │
│ ▼ TAGS            │ ● Whisper test       │                                  │
│   #work      (47) │   Testing new mode   │  - Infrastructure budget +12%    │
│   #finance   (12) │   2 days ago         │    approved for cloud migration  │
│   #personal  (31) │                      │                                  │
│   #dictated  (89) │ ● WWDC Notes         │  Action items were assigned to   │
│                   │   Session summaries  │  team leads. Follow-up meeting   │
│                   │   Jun 12             │  scheduled for Thursday 3pm.     │
│                   │                      │                                  │
│                   │                      │                                  │
├───────────────────┴──────────────────────┴──────────────────────────────────┤
│  142 notes                                                    312 words      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9.3 Dictation Overlay / HUD

The Dictation HUD is a floating, translucent panel that appears during active dictation. It is implemented as a borderless `NSWindow` (macOS) or custom overlay `UIViewController` (iOS) with `NSVisualEffectView` / `UIVisualEffectView` background using `.hudWindow` / `.systemThinMaterial` material. The window level is set to `NSWindow.Level.floating` so it stays above application content without obscuring menu bars or docks.

**HUD Contents (top to bottom):**
1. **Destination row** — Shows where dictation output will go: "→ Safari" (frontmost app icon + name) or "→ New Note". A tap/click on this row toggles between injecting into the frontmost app and saving as a new note. The destination is determined automatically based on context (if a text field is focused in the frontmost app, defaults to injection; otherwise defaults to new note) but is always user-overridable. This is the single most important UX element in the HUD — users must always know where their words are going.
2. **Mode badge** — Colored pill: "Append" (blue), "Replace" (orange), "Command" (purple), "Whisper" (teal)
3. **Waveform visualizer** — Real-time amplitude bar graph (20 bars), 60 fps updates; replaced by a simple animated ellipsis when Reduce Motion is enabled
4. **Live transcript preview** — Scrolling single-line text field showing last ~80 characters of recognized text; confirmed words shown in primary color, unconfirmed in secondary/gray
5. **AI processing indicator** — Small spinner + "Enhancing..." label, visible only when AI post-processing is running
6. **Action buttons** — Three buttons: "Edit" (makes the preview text editable for user modification before injection), "Cancel" (✕, discards session), and "Commit" (✓, injects/saves the text). "Edit" expands the preview area to a multi-line editable text field. Pressing `Escape` triggers Cancel; pressing `Return` triggers Commit.

**Position Options (user-configurable):**
- Top-center of screen (default)
- Bottom-center of screen

Note: "Near cursor" positioning was considered but rejected — a floating overlay that repositions as the user types in other apps is disorienting. Fixed positions provide a stable visual anchor.

**Auto-dismiss:**
- HUD dismisses 1.5 seconds after dictation session ends and text has been injected (configurable: 0.5s–5s)
- No auto-dismiss if an error state is active; user must dismiss manually
- HUD is semi-transparent (85% opacity) when cursor is moved into its bounding rect to allow seeing content beneath

**Undo Support:**
- After text injection into a third-party app, an "Undo Last Dictation" button appears in the HUD for 5 seconds
- For clipboard fallback injections (Cmd+V paste), Cmd+Z works natively in the target app — no additional mechanism needed
- For AX API injections, the undo button re-reads the target text field via `AXUIElement`, selects the injected range, and deletes it
- The injected text is always stored in the `DictationSession` record regardless of injection success, so it can be recovered

**Injection Failure Recovery:**
- If text injection fails (target app lost focus, text field disappeared, AX permission revoked) after all retry attempts:
  - A persistent notification appears: "Dictation couldn't be inserted into [app name]. Your text has been saved." with a "Copy to Clipboard" button
  - The dictated text is automatically saved as a new note tagged `#failed-injection` with the target app name in metadata
  - The text is NEVER silently lost — this is a core design invariant

```
┌──────────────────────────────────────────────────┐
│  → Safari                              [⇄ Note]  │
│  ● APPEND                                        │
│  ▁▂▄▆▇▆▅▃▂▁▂▃▄▅▆▅▄▃▂▁▂▃▄▆▇▅▄▃▁                │
│  "...and the second agenda item was the bud|"    │
│  ◌ Enhancing...                                   │
│                          [Edit] [Cancel] [Commit] │
└──────────────────────────────────────────────────┘
```

---

## 9.4 Settings Panels

Settings are presented in a standard macOS `Settings` scene (`.settings` WindowGroup) using a tabbed sidebar layout on macOS 13+ style, and as a pushed `NavigationStack` on iOS.

### General
- **Activation Mode**: segmented control — Push-to-talk / Toggle / Auto-detect silence
- **Global Hotkey**: key recorder field (default `⌘⇧Space`)
- **Default Dictation Mode**: Append / Replace / Command
- **Language & Region**: primary language picker; secondary language for code-switching
- **Appearance**: System / Light / Dark
- **Menu Bar Icon**: Show always / Show when active / Hide
- **Launch at Login**: toggle
- **Show Dictation HUD**: toggle; HUD position picker (top-center / bottom-center / near cursor)
- **HUD Auto-dismiss Delay**: slider 0.5s–5s

### AI Providers
- List of configured providers with enable/disable toggles
- **Add Provider** button → sheet with provider type picker (OpenAI, Anthropic Claude, Ollama, Apple Intelligence, Custom)
- Per-provider configuration form:
  - API key field (stored in Keychain; displayed masked)
  - Base URL override (for proxies or self-hosted)
  - Model selector (fetched from provider on connection test)
  - Default processing pipeline toggles: Grammar, Punctuation, Filler Removal, Formatting
- **Test Connection** button → shows latency and model confirmation
- Priority ordering (drag to reorder; top provider used by default, falls back down list)

### Dictionary & Snippets
- **Personal Dictionary**: searchable list of custom words; Add / Remove / Import from CSV
- **Snippets**: table of trigger → expansion pairs; inline editing; supports `$DATE$`, `$TIME$`, `$CLIPBOARD$` tokens
- Import/Export snippets as JSON

### Notes
- **Default Folder**: picker for new note destination
- **Auto-save Interval**: immediate / 5s / 30s / manual only
- **Default Export Format**: Markdown / Plain Text / PDF
- **Note Title Generation**: Manual / First sentence / AI-generated (requires AI provider)
- **Attachment Storage**: Inline (default) / Referenced files

### App Profiles
- List of per-application overrides
- **Add Profile** → app picker (from running apps or `/Applications`)
- Per-profile settings: dictation mode override, AI pipeline override, injection method override, hotkey override
- Enable/disable individual profiles without deleting

### Privacy
- **Permission Status Dashboard**: microphone (granted/denied with system settings deeplink), accessibility (granted/denied), iCloud (enabled/disabled)
- **Audio Retention**: Never save audio (default) / Save encrypted to Notes / Prompt each session
- **Optional Analytics**: toggle for anonymous usage statistics; expandable detail of exactly what is collected
- **Clear All Data** button (destructive, confirmation required): deletes local notes database, audio cache, AI conversation history

### AI Usage & Cost
- **Monthly summary**: total tokens processed this month, broken down by provider
- **Estimated cost**: calculated from known per-token pricing for each provider (OpenAI, Anthropic); updated in real time as dictations are processed
- **Per-provider breakdown**: chart showing usage distribution across providers
- **Daily average**: average tokens/day and estimated daily cost
- **Cost alerts**: optional notification when estimated monthly cost exceeds a user-configured threshold (default: off)
- Note: Apple Intelligence and Ollama show token counts but no cost estimate (they are free/local)

### About & Updates
- App version, build number, commit SHA
- **Check for Updates** button (direct distribution) / link to App Store (App Store distribution)
- **Update Channel**: Stable / Beta / Nightly (direct distribution only)
- Links: GitHub repository, documentation, report a bug, changelog
- Open-source license acknowledgments list

---

## 9.5 Onboarding Flow

Onboarding is presented as a full-window sheet on first launch, implemented as a `NavigationStack`-based wizard. State is tracked in `UserDefaults` with key `onboardingCompleted`. The onboarding is deliberately minimal — for a 2–10 person internal tool, getting users to their first dictation as fast as possible is more important than comprehensive configuration. Advanced setup (activation method, hotkey, AI providers) is handled via contextual discovery on first relevant use.

**Step 1 — Welcome**
- Full-bleed illustration of the app concept
- Headline: "Your voice, your notes."
- Subheadline: brief one-sentence description
- Primary CTA: "Get Started"

**Step 2 — Microphone Permission**
- Explanation: "Murmur needs microphone access to transcribe your speech. Audio is processed locally and never stored unless you choose to."
- Button: "Grant Microphone Access" → triggers `AVAudioApplication.requestRecordPermission`
- If denied: inline guidance to open System Settings > Privacy > Microphone

**Step 3 — Accessibility Permission (macOS only)**
- Explanation: "To insert text into any app on your Mac, Murmur needs Accessibility access. This is used only to find the text cursor and inject transcribed text."
- Button: "Open Accessibility Settings" → opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Poll for permission grant every 2 seconds; auto-advance when granted

**Step 4 — All Set**
- Confirmation: "You're ready to go. Press [default hotkey] to start dictating."
- Shows the default hotkey prominently
- "Open Notes Library" / "Start Dictating" dual CTAs
- Sets `onboardingCompleted = true`

**Contextual Discovery (post-onboarding, triggered on first relevant use):**
- **Activation method**: On first dictation, a brief tooltip explains the default hold-to-dictate behavior and offers "Try other modes" link to Settings
- **Hotkey customization**: If the default hotkey conflicts with another app, a non-blocking notification offers to open Settings > General > Hotkey
- **AI provider setup**: On the user's first dictation longer than 30 seconds, a one-time prompt appears: "Want AI to clean up your dictation? Set up an AI provider in Settings." with "Set Up" and "Not Now" buttons
- **Tutorial**: A "?" help button in the menu bar popover opens a 3-slide in-app tutorial at any time

*Note: The previous 8-step onboarding has been consolidated to 4 steps (3 on iOS, which skips the Accessibility Permission step). Advanced configuration that was previously in Steps 4–7 is now handled via contextual discovery as described above.*

---

## 9.6 iOS-Specific UI Adaptations

### Main App Layout
The iOS app uses a `TabView` with four tabs at the bottom:

| Tab | Icon | Content |
|---|---|---|
| Notes | `note.text` | `NavigationSplitView` (iPad) or flat `NavigationStack` (iPhone) replicating sidebar + list + editor |
| Dictate | `mic.fill` | Full-screen dictation view with large waveform, live transcript, mode picker |
| Search | `magnifyingglass` | Full-text search across all notes with filters |
| Settings | `gearshape` | Pushed settings stack |

On iPad, the Notes tab uses a three-column `NavigationSplitView` matching the macOS layout. On iPhone, the sidebar is accessed via the navigation bar leading button.

### Keyboard Extension
The keyboard extension (`VoiceInputKeyboardExtension` target) provides a custom key in the system keyboard row. Implementation:
- Subclasses `UIInputViewController`
- Presents a microphone button row above the system keyboard
- On tap: activates `AVAudioEngine` capture **within the extension process** and streams raw audio buffers to the main app via the shared App Group container (using a memory-mapped file or `CFMessagePort` for low-latency IPC)
- **`SpeechAnalyzer` runs in the main app process**, not in the extension. This is a deliberate design decision: the iOS keyboard extension has a strict ~120 MB memory limit, and `SpeechAnalyzer` combined with the extension UI may exceed this on some devices. The main app runs `SpeechAnalyzer` on the received audio and streams transcription results back to the extension via the same IPC channel.
- The extension calls `insertText(_:)` / `deleteBackward()` APIs to inject transcription results received from the main app
- AI post-processing is handled entirely in the main app process as part of the transcription pipeline
- A narrow waveform strip and live preview label appear in the extension UI during active recording

### Share Extension
The share extension (`VoiceInputShareExtension` target) accepts:
- `public.plain-text`
- `public.url`
- `public.image` (saved as note attachment)

The extension presents a minimal compose sheet: destination folder picker, optional title, optional AI summarization toggle. On save, data is written to the shared App Group container; the main app ingests it on next launch/foreground.

### Widgets (WidgetKit)
Two widget types:
1. **Quick Dictate** (small): Single-tap button that deep-links to the Dictate tab with dictation auto-starting via URL scheme `projectv://dictate`
2. **Recent Notes** (medium/large): List of 3–5 most recent notes with title and relative timestamp; each row deep-links to the specific note

### Key Differences from macOS Layout
- No menu bar component; dictation is initiated from the Dictate tab or keyboard extension
- No global hotkey; activation is tap-based
- No `AXUIElement` text injection; relies solely on keyboard extension or clipboard
- Settings accessible from tab bar rather than menu bar popover
- iCloud sync indicator shown in navigation bar rather than status bar
- Formatting toolbar collapses to a scrollable row above the software keyboard

---

## 9.7 Sync Conflict Resolution UI

When `CKSyncEngine` detects a conflict that cannot be resolved automatically (specifically, note body conflicts where both the local and remote versions have been modified since the last common ancestor), a conflict copy is created and the user is prompted to resolve it.

**Conflict Indicator:**
- A "Conflicts" badge appears in the sidebar (below Smart Folders) showing the count of unresolved conflicts
- A non-blocking banner notification appears: "Sync conflict detected in '[note title]'. Tap to resolve."

**Conflict Resolution View:**
- Accessible by tapping the Conflicts badge in the sidebar or the notification
- Displays a side-by-side diff view showing "Your Version" (left) and "Other Device's Version" (right)
- Differences are highlighted: green for additions, red for deletions
- Three action buttons:
  - **Keep Mine** — discards the remote version; the local version becomes authoritative
  - **Keep Theirs** — discards the local version; the remote version is applied
  - **Keep Both** — retains both versions as separate notes (the conflict copy remains as "[title] (conflict copy)")
- After resolution, the conflict copy is deleted (for Keep Mine/Keep Theirs) or renamed (for Keep Both)

**Automatic Resolution (no UI required):**
- For non-body fields (title, isPinned, tags, folder), field-level last-writer-wins is applied automatically
- For note body: if only one side modified the body since the last sync, the modified version wins silently
- The conflict resolution UI is only shown when both sides modified the note body

```
┌─────────────────────────────────────────────────────────────────┐
│  Resolve Conflict — "Meeting Notes — Q2 Budget"                │
├────────────────────────────┬────────────────────────────────────┤
│  Your Version (this Mac)   │  Other Version (iPhone)            │
│  Modified: Today 2:14 PM   │  Modified: Today 2:16 PM           │
├────────────────────────────┼────────────────────────────────────┤
│  The Q2 budget review      │  The Q2 budget review              │
│  covered headcount         │  covered headcount                 │
│  projections through       │  projections through               │
│  fiscal year end.          │  fiscal year end.                  │
│                            │                                    │
│- Headcount: freeze at      │- Headcount: +freeze+ pause at     │
│  current levels through Q3 │  current levels through Q3         │
│                            │                                    │
│- Infrastructure budget     │- Infrastructure budget             │
│  +12% approved             │  +15% approved (revised)           │
├────────────────────────────┴────────────────────────────────────┤
│            [Keep Mine]  [Keep Theirs]  [Keep Both]              │
└─────────────────────────────────────────────────────────────────┘
```

---

# Section 10: Platform-Specific Requirements

## 10.1 macOS 26+ Requirements

### Minimum OS
**macOS 26.0 (Tahoe)** is the minimum supported version. This provides access to `SpeechAnalyzer` (introduced in macOS 26), the updated `NSWritingToolsCoordinator` API, and the latest SwiftUI layout primitives used by the editor.

### Hardware Requirements
- **Apple Silicon (M1 or later)** required for on-device `SpeechAnalyzer` usage. Intel Mac support is explicitly out of scope; the `SpeechAnalyzer` framework does not support x86_64 targets.
- Minimum 8 GB RAM recommended (not enforced at launch, but noted in documentation)
- Microphone (built-in or external USB/Bluetooth)

### Entitlements

| Entitlement | Key | Justification |
|---|---|---|
| Microphone | `com.apple.security.device.audio-input` | Required for speech capture |
| Accessibility | `com.apple.security.temporary-exception.accessibility` or AX API usage | Required for text injection via AXUIElement |
| iCloud (CloudKit) | `com.apple.developer.icloud-services` → `CloudKit` | Required for cross-device sync |
| iCloud (Documents) | `com.apple.developer.icloud-container-identifiers` | Required for iCloud Drive storage fallback |
| Network Client | `com.apple.security.network.client` | Required for cloud AI provider API calls |
| User Selected Files (Read/Write) | `com.apple.security.files.user-selected.read-write` | Required for note import/export |
| App Groups | `com.apple.security.application-groups` | Required for sharing data with menu bar helper |

### App Sandbox
The app runs fully sandboxed. The menu bar helper is a separate lightweight process (`VoiceInputMenuBarHelper` target) that communicates with the main app via XPC. The helper is registered as a Login Item using `SMAppService.mainApp` (macOS 13+ API) so it persists across restarts without requiring legacy Login Items.

### Notarization
All builds distributed outside the Mac App Store (GitHub Releases, Homebrew Cask) are notarized via Apple Notary Service using `notarytool`. The Xcode Cloud workflow handles signing and notarization automatically for release builds. The `.dmg` is stapled (`xcrun stapler staple`) before distribution.

### Global Hotkey Registration
Global hotkeys are registered using the `CGEventTap` API within the accessibility-privileged helper process. Fallback to `NSEvent.addGlobalMonitorForEvents` for environments where CGEventTap is unavailable. Hotkey conflict detection checks against system-reserved shortcuts at registration time and warns the user.

---

## 10.2 iOS Requirements

### Minimum OS
**iOS 19.0** is the minimum supported version, providing access to `SpeechAnalyzer` on iOS, updated `UITextInteraction` APIs, and WidgetKit improvements.

### Keyboard Extension
- Target type: `UIInputViewController` subclass
- Info.plist key: `NSExtensionPrincipalClass` pointing to `VoiceKeyboardViewController`
- `RequestsOpenAccess` = `YES` required for App Group data sharing and main app IPC
- Audio session category: `.record` with `.allowBluetooth` option
- The extension process has a strict memory limit (~120 MB). **`SpeechAnalyzer` does NOT run in the extension process.** Instead, the extension captures audio via `AVAudioEngine` and streams raw buffers to the main app via the shared App Group container (memory-mapped file or `CFMessagePort`). The main app runs `SpeechAnalyzer` and all AI post-processing, streaming transcription results back. This architecture keeps the extension well within its memory budget.
- Transcript delivery: the main app writes transcription results to the shared App Group; the extension reads and calls `insertText(_:)` to inject into the host app.

### Share Extension
- Target type: `UIViewController` + `NSExtensionContext`
- Supported UTI types: `public.plain-text`, `public.url`, `public.image`, `public.file-url`
- Maximum file size accepted: 10 MB (larger files prompt user to open in main app)
- Data written to App Group container directory: `group.com.projectv.shared/incoming/`

### Background Audio Session Handling
- Audio session category `.record` is activated only during active dictation; deactivated immediately after
- No continuous background audio monitoring; the app does not request background audio entitlement by default
- If a dictation session is interrupted (phone call, Siri activation), the session is paused and the partial transcript is preserved; user is prompted to resume or discard on return to foreground

### WidgetKit
- Widget bundle target: `VoiceInputWidgets`
- Timelines updated via `WidgetCenter.shared.reloadTimelines(ofKind:)` when notes are modified
- Quick Dictate widget uses `Link` with deep-link URL; no custom intent required
- Recent Notes widget uses `AppIntentTimelineProvider` for dynamic content

### App Clips
App Clips are out of scope for Phase 1–3 but are noted as a future consideration for a "Quick Dictate" clip accessible via NFC tag or QR code in physical locations (e.g., meeting rooms).

### Push Notifications for Sync
`CKSyncEngine` automatically manages push notification subscriptions for the app's CloudKit zones. When a record is modified on another device, `CKSyncEngine` receives the silent push and triggers a fetch cycle, invoking the `CKSyncEngineDelegate` methods to apply changes. No manual `CKDatabaseSubscription` registration is required.

---

## 10.3 Shared Framework

### Swift Package Structure

The repository is organized as an Xcode workspace containing:
- `VoiceInput.xcodeproj` — main Xcode project with all app targets
- `Packages/VoiceInputCore` — shared Swift Package (multiplatform)
- `Packages/VoiceInputUI` — shared SwiftUI component library

`VoiceInputCore` is platform-agnostic and compiles for macOS, iOS, and (future) visionOS. It contains:

| Module | Contents |
|---|---|
| `Models` | `Note`, `Folder`, `Tag`, `Snippet`, `DictationSession` model types (SwiftData `@Model` classes) |
| `NoteStore` | CRUD interface over SwiftData `ModelContext`; query builders for search and smart folders |
| `SyncEngine` | CloudKit sync coordinator; conflict resolution logic; sync state machine |
| `AIProvider` | `AIProviderProtocol`, `AIRequest`/`AIResponse` types, `AIProviderRegistry` |
| `SpeechEngine` | `SpeechEngineProtocol`, `SpeechAnalyzerEngine` concrete implementation, mock for testing |
| `PersonalDictionary` | Dictionary management, snippet expansion engine |
| `SearchIndex` | Full-text search index built on `NaturalLanguage.framework` tokenization |

**Platform-specific code (not in shared package):**

| Platform | Location | Contents |
|---|---|---|
| macOS | `VoiceInput/macOS/` | `AXTextInjector`, `GlobalHotkeyMonitor`, `MenuBarController`, `NSPasteboard` integration |
| iOS | `VoiceInput/iOS/` | `KeyboardExtensionBridge`, `ShareExtensionHandler`, `UIPasteboard` integration |
| Both | `VoiceInput/Shared/` | `DictationCoordinator`, app lifecycle, SwiftUI root views |

Dependency on `VoiceInputCore` is declared in each target's `Package.swift` dependency list. The shared package has zero third-party dependencies; all functionality relies on Apple frameworks.

---

# Section 11: Accessibility Specification

## 11.1 VoiceOver Support

Every interactive element in the application has:
- An `accessibilityLabel` describing what it is (e.g., "Start Dictating button")
- An `accessibilityHint` for non-obvious actions (e.g., "Double-tap to begin voice transcription")
- An `accessibilityValue` where current state is relevant (e.g., "Mode: Append")
- An `accessibilityIdentifier` matching the element's semantic role, used by UI tests

**Custom Rotor Actions for Note Navigation:**
A custom VoiceOver rotor is registered on the note list and editor pane, providing the following actions navigable with the rotor gesture:
- "Notes" — jump between note items in the list
- "Headings" — jump between H1/H2/H3 headings in the editor body
- "Tags" — jump between tag chips on the current note
- "Dictation Insertions" — jump between text regions that were inserted via dictation (marked with a custom accessibility attribute)

**Dictation State Announcements:**
State changes post `UIAccessibility.post(notification:argument:)` / `NSAccessibility.post(element:notification:)` announcements:
- Session starts: "Dictation started. Speak now."
- Session ends: "Dictation complete. [N] words inserted."
- Processing: "Enhancing text with AI."
- Error: "Dictation failed. [Error description]."
- Mode change: "Mode changed to [mode name]."

Announcements use `.announcement` notification type. If Reduce Motion + audio is the user's preferred interaction mode, visual-only state changes are not made; all state is surfaced through accessibility notifications.

**Reading Order:**
Complex layouts explicitly define reading order using `accessibilitySortPriority` on macOS and `accessibilityRespondsToUserInteraction` + group containers on iOS. The main window reading order is: sidebar → note list → editor toolbar → editor title → editor tags → editor body → word count footer.

---

## 11.2 Dynamic Type

All text in the application uses semantic `Font` styles (`.title`, `.headline`, `.body`, `.caption`) rather than fixed point sizes. This ensures text scales with the user's selected content size category from `.extraSmall` to `.accessibilityExtraExtraExtraLarge`.

**Layout adaptation rules:**
- Sidebar and note list columns collapse gracefully: at `accessibilityLarge` and above, the sidebar and list columns stack vertically rather than side-by-side
- The editor toolbar wraps to two rows at `accessibilityMedium` and above; icons grow proportionally
- Note title field uses `.largeTitle` style, which scales significantly; the layout reserves sufficient vertical space and does not clip
- Tag chips use `.caption2` minimum; at accessibility sizes, chips expand and wrap to multiple lines rather than truncating
- Minimum touch/click target size is enforced at 44 × 44 pt on iOS for all interactive elements, regardless of text size

**Testing:**
All views are previewed in SwiftUI Previews at `.extraSmall`, `.large`, and `.accessibilityExtraExtraExtraLarge` content size categories. Preview coverage for Dynamic Type is included in the UI test plan.

---

## 11.3 High Contrast & Color

**Increase Contrast Support:**
When the user enables Increase Contrast in System Settings / Accessibility settings, the app:
- Uses `Color(.label)` / `Color(.systemBackground)` semantic colors throughout to automatically adapt
- Replaces translucent materials (`.hudWindow`, `.sidebar`) with fully opaque equivalents
- Increases border widths on interactive controls from 0.5 pt to 1.5 pt
- Strengthens focus ring visibility (2 pt → 4 pt ring, higher contrast color)

**Color-independent information:**
Tag colors are decorative only. Tag identification always includes the tag name as text. In table/list views, tags are never represented by color swatch alone — the label is always visible. Dictation mode is indicated by both color (blue/orange/purple/teal) and the mode name text in the HUD badge. Error states use both a red color and an icon or text label — never color alone.

**Dark Mode / Light Mode:**
All custom colors are defined as `Color` assets in the asset catalog with both Light and Dark appearances. No hardcoded hex colors are used in view code. All custom images and icons have both light and dark variants or use template rendering mode.

---

## 11.4 Keyboard Navigation (macOS)

The application supports full keyboard navigation; every interactive element is reachable and operable without a mouse.

**Tab Order (Main Window):**
1. Sidebar search field
2. Sidebar folder/tag items (arrow keys to navigate within sections)
3. Note list (arrow keys to navigate items; Return to open in editor)
4. Editor toolbar buttons (left-to-right)
5. Editor title field
6. Editor tag chips + "Add tag" field
7. Editor body
8. Word count footer

**Focus Ring:**
SwiftUI's default focus ring is supplemented with a custom `FocusedBorder` modifier that renders a 3 pt rounded-rect ring in the accent color. This ring meets WCAG 2.1 Level AA contrast requirements against both light and dark backgrounds.

**Keyboard Shortcuts Table:**

| Action | Shortcut |
|---|---|
| Start/Stop Dictating | `⌘⇧Space` (global, configurable) |
| New Note | `⌘N` |
| Open Notes Library | `⌘⇧N` |
| Search | `⌘F` |
| Bold | `⌘B` |
| Italic | `⌘I` |
| Underline | `⌘U` |
| Heading 1 | `⌘⌥1` |
| Heading 2 | `⌘⌥2` |
| Heading 3 | `⌘⌥3` |
| Insert Checklist | `⌘⇧L` |
| Export Note | `⌘⇧E` |
| Delete Note | `⌘⌫` |
| Move to Folder | `⌘⇧M` |
| Open Settings | `⌘,` |
| Close Window | `⌘W` |
| Cancel Dictation | `Escape` |
| Switch to Next Mode | `⌘⌥M` |

All shortcuts are discoverable via the macOS menu bar and the Help menu's shortcut reference.

---

## 11.5 Reduced Motion

When the user enables "Reduce Motion" in System Settings or Device Settings:

- The menu bar icon state change uses an instant swap rather than a crossfade animation
- The HUD appearance and dismissal uses `.opacity` transition (crossfade) instead of the default `.move(edge:)` + scale animation
- The waveform visualizer switches from animated bar graph to a static amplitude level indicator (a single bar that updates at 4 fps instead of 60 fps) or a simple pulsing dot
- Note list reordering uses instant repositioning rather than spring animations
- Sidebar collapse/expand transitions use crossfade instead of slide
- Onboarding step transitions use `.opacity` instead of slide

All animation modifiers in the codebase use `withAnimation(.easeInOut)` wrapped in a check:

```swift
let animation: Animation? = accessibilityReduceMotion ? nil : .easeInOut
withAnimation(animation) { ... }
```

A shared `@Environment(\.accessibilityReduceMotion)` value is read at the view hierarchy root and propagated via environment.

---

## 11.6 Accessibility Audit Checklist

The following checklist is completed before each release candidate:

**Perceivable:**
- [ ] All non-text content (icons, waveform, images) has a text alternative
- [ ] All audio-only state changes (recording active) have visual indicators
- [ ] Color contrast ratio ≥ 4.5:1 for normal text, ≥ 3:1 for large text (verified with Xcode Accessibility Inspector)
- [ ] No information conveyed by color alone
- [ ] Text resizes to 200% without loss of content or functionality
- [ ] Reduce Motion preference respected for all animations

**Operable:**
- [ ] All functionality accessible via keyboard (macOS) / switch access (iOS)
- [ ] No keyboard traps; Escape always returns focus to previous location
- [ ] All interactive elements meet 44×44 pt minimum touch target (iOS)
- [ ] Focus ring visible on all focusable elements (macOS)
- [ ] Custom rotor actions registered and functional (VoiceOver)
- [ ] No flashing content that exceeds 3 Hz (no seizure risk)

**Understandable:**
- [ ] Language of app is declared (`CFBundleDevelopmentRegion`)
- [ ] Input errors are identified and described in text
- [ ] Labels are descriptive and consistent throughout
- [ ] All abbreviations are expanded at first use in UI text (e.g., "AI (Artificial Intelligence)")

**Robust:**
- [ ] All interactive controls pass `XCUIApplication.accessibilityAudit()` (Xcode 15+ API)
- [ ] VoiceOver linear reading order verified for all main views
- [ ] Dynamic Type verified at `.accessibilityExtraExtraExtraLarge` for all views
- [ ] High Contrast mode verified: no information lost, no layout breakage
- [ ] Tested with VoiceOver on macOS and iOS (manual session)
- [ ] Tested with Switch Control on iOS (manual session)
- [ ] Tested with Voice Control on macOS (manual session)

---

# Section 12: Security & Privacy

## 12.1 Local-First Data Architecture

Murmur follows a strict local-first principle: the SwiftData persistent store on the local device is the authoritative source of truth at all times. iCloud/CloudKit sync is additive — it propagates changes but never serves as the primary data source. Consequences of this approach:

- The app is fully functional offline; no network access is required for core dictation and note-taking
- CloudKit sync failures are silent background errors that retry; they do not block user-facing operations
- On first launch, the note store is created locally even if iCloud is available; sync is enabled asynchronously after setup
- Conflict resolution always prefers the version with the later `modifiedAt` timestamp; a copy of the conflicting version is preserved as an auto-generated note titled "Conflict copy — [original title] — [timestamp]"
- Deleted notes are soft-deleted locally (tombstone record) for 30 days before permanent deletion, allowing sync propagation of deletes to other devices

---

## 12.2 Encryption

**Data at Rest:**
All files in the app's container directory are protected with `NSFileProtectionComplete` (mapped to iOS Data Protection Class A). On macOS, app container files receive the equivalent protection via APFS encryption tied to the user's login credentials.

**Keychain:**
All credential material — AI provider API keys, OAuth tokens, CloudKit tokens — is stored in the system Keychain with:
- `kSecAttrAccessible`: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- `kSecAttrSynchronizable`: `false` (credentials are per-device, not synced via iCloud Keychain)
- Access group: `$(AppIdentifierPrefix)com.projectv.credentials`

**CloudKit:**
All CloudKit records are stored in the app's private CloudKit database, which is encrypted at rest by Apple and transmitted over TLS. No public CloudKit database is used. Record fields containing note body text use CloudKit's `CKRecord.encryptedValues` API (available macOS 12+/iOS 15+) to enable end-to-end encryption for supported fields.

**No custom cryptography** is implemented. The project relies entirely on platform-provided cryptographic primitives. Any future requirement for additional encryption must use `CryptoKit` framework primitives and be reviewed by a security-knowledgeable contributor before merging.

---

## 12.3 Audio Data Handling

Audio data is among the most sensitive data the application handles. The following invariants are enforced:

1. **No audio written to disk by default.** `AVAudioEngine` tap buffers are allocated in memory and passed directly to `SpeechAnalyzer`. No `AVAudioFile` is created during a standard session.
2. **Buffer zeroing.** After `SpeechAnalyzer` completes processing a buffer, the buffer's underlying memory is explicitly zeroed using `memset` before the buffer object is released. This prevents residual audio data from persisting in heap memory longer than necessary.
3. **Optional audio recording.** Users may opt in to saving audio recordings of dictation sessions. When enabled:
   - Audio is written to an `AVAudioFile` in the app's `Application Support` directory
   - The file is created with `NSFileProtectionComplete`
   - A corresponding `Note` record links to the audio file by relative path
   - The user is reminded at opt-in that audio files may contain sensitive information
4. **No cloud audio transmission.** Even when cloud AI providers are used, audio is never transmitted to cloud AI APIs. Only the transcribed text is sent for post-processing.
5. **Audio session deactivation.** `AVAudioSession.sharedInstance().setActive(false)` (iOS) is called immediately after each dictation session ends, regardless of outcome.

---

## 12.4 Telemetry & Analytics

**Default: zero telemetry.** On a fresh install with default settings, the application makes no outbound network connections except to cloud AI provider APIs explicitly configured by the user.

**Optional anonymous analytics (opt-in only):**
If the user explicitly enables analytics in Settings > Privacy, the following aggregate statistics are collected and transmitted:
- Session count per day (integer)
- Word count per day (integer)
- Active AI provider type (enum string, e.g., "openai" — never the model name or API key)
- App version and OS version
- Crash reports (via Apple's built-in crash reporter, not a third-party SDK)

The following are explicitly **never collected**, even with analytics enabled:
- Note content, titles, or metadata
- Transcribed text
- Folder or tag names
- AI provider API keys or account identifiers
- Device identifier (no IDFA, no device fingerprinting)
- IP address (analytics are submitted via an anonymizing relay if technically feasible)

**No third-party analytics SDKs** (e.g., Mixpanel, Amplitude, Firebase Analytics, Sentry) are included in the project. Any pull request adding such a dependency will be rejected at review.

The Settings > Privacy panel displays exactly what data is collected and links to the project's privacy policy on GitHub.

---

## 12.5 Clinical Content Handling

Murmur is built primarily for Unconventional Psychotherapy, where some dictated content will be clinically sensitive (therapy session notes, client names, diagnoses, treatment plans). This section addresses the privacy requirements specific to this context.

**Clinical Mode**

A "Clinical Mode" toggle is available in Settings > Privacy > Clinical Mode. When enabled:
- **All cloud AI providers are disabled.** Only on-device providers (Apple Intelligence, Ollama running locally) are available for AI post-processing. Cloud providers (OpenAI, Anthropic) are grayed out in the provider list with an explanation: "Cloud AI is disabled in Clinical Mode to protect client confidentiality."
- **No network calls** are made during dictation or AI processing — only CloudKit sync (which uses end-to-end encryption via `CKRecord.encryptedValues`) and Sparkle update checks are permitted
- **A persistent "Clinical Mode" badge** appears in the menu bar icon and HUD to confirm the mode is active
- Clinical Mode can also be enabled per-app via App Profiles. For example, the practice's EHR app can have Clinical Mode forced on while Slack and email use standard settings.

**Auto-Detection (Optional)**

An optional heuristic detects when the user may be dictating clinical content based on:
- The frontmost app matches a configured list of clinical applications (EHR, therapy note-taking tools)
- The personal dictionary contains clinical terms that appear in the current dictation (configurable threshold)

When detected, if Clinical Mode is not already active, a non-blocking prompt appears: "This looks like clinical content. Switch to Clinical Mode?" with "Yes" and "Not now" options.

**HIPAA Considerations**

While Murmur is not marketed as a HIPAA-compliant tool, the following design decisions align with HIPAA technical safeguard requirements:
- **Encryption at rest**: All local data is protected by `NSFileProtectionComplete` (iOS) or APFS user-level encryption (macOS)
- **Encryption in transit**: CloudKit sync uses end-to-end encryption for note body content via `CKRecord.encryptedValues`
- **Access control**: Device-level authentication (Face ID, Touch ID, password) is the access control boundary
- **Audit trail**: Every dictation session is logged with timestamp, source app, and processing path (on-device vs. cloud) in the `DictationSession` record
- **No cloud audio**: Audio never leaves the device; only transcribed text is sent to cloud AI providers (and only when Clinical Mode is off)
- **BAA note**: If the practice requires a Business Associate Agreement (BAA) with cloud AI providers, the user must obtain BAAs directly from OpenAI, Anthropic, etc. Murmur does not serve as a business associate — it is a locally-installed tool. Clinical Mode eliminates the need for cloud AI BAAs entirely.

---

## 12.6 Network Security

**Transport Security:**
All outbound HTTP connections use HTTPS with TLS 1.3. App Transport Security (ATS) is enabled with no exceptions. `NSAllowsArbitraryLoads` is `false` in all build configurations.

**Certificate Pinning:**
For the first-party AI provider integrations (OpenAI and Anthropic), public key pinning is implemented using `URLSession` delegate method `urlSession(_:didReceive:completionHandler:)`. Pinned public key hashes are bundled in the app and verified on each connection. Pin rotation is handled by including both current and next-rotation pins simultaneously and updating via a minor app update.

Ollama (local) connections are to `localhost` and are exempt from certificate requirements. Custom provider base URLs supplied by the user are not pinned (user assumes responsibility).

**No external resource loading:**
The note editor does not load remote images or resources. Markdown rendering is performed locally; any URLs in note content are rendered as plain text links and only fetched when the user explicitly taps/clicks them. No tracking pixels, web fonts from CDNs, or external stylesheets are loaded.

**Network activity indicator:**
When an outbound network request is in flight (cloud AI post-processing, CloudKit sync, update check), a small "cloud with arrow" indicator appears in the macOS status bar area of the main window and in the iOS navigation bar. This gives users a transparent signal that data is being transmitted.

---

## 12.7 Permissions Transparency

Settings > Privacy displays a live dashboard of all permissions the app has requested:

| Permission | Status | Used For | Revoke |
|---|---|---|---|
| Microphone | Granted / Denied | Voice capture for dictation | "Manage in System Settings" → deeplink |
| Accessibility | Granted / Denied (macOS) | Text injection into other apps | "Manage in System Settings" → deeplink |
| iCloud / CloudKit | Enabled / Disabled | Syncing notes across your devices | "Manage in System Settings" → deeplink |
| Local Network (if Ollama) | Granted / Denied | Connecting to local Ollama server | "Manage in System Settings" → deeplink |
| Notifications | Granted / Denied | Sync conflict alerts | "Manage in System Settings" → deeplink |

Permission requests are made contextually, not all at once at launch:
- **Microphone**: Requested on first dictation attempt
- **Accessibility** (macOS): Requested during onboarding Step 3, with explanation
- **CloudKit**: Requested when user first enables sync in Settings > Notes
- **Notifications**: Requested only when sync is enabled and background push is needed

Each first-time permission request is preceded by a custom pre-prompt screen explaining why the permission is needed and what it will be used for, before triggering the system permission dialog.

---

## 12.8 App Sandbox Scope

All sandbox entitlements are declared with minimum-necessary scope:

| Entitlement | Value | Justification |
|---|---|---|
| `com.apple.security.app-sandbox` | `true` | Required for App Store; default for all builds |
| `com.apple.security.device.audio-input` | `true` | Core function: voice capture |
| `com.apple.security.network.client` | `true` | Cloud AI API calls; CloudKit sync; update checks |
| `com.apple.security.files.user-selected.read-write` | `true` | Import/export notes to user-chosen locations |
| `com.apple.security.files.downloads.read-write` | `false` | Not needed; user selection covers this |
| `com.apple.security.application-groups` | `group.com.projectv.shared` | Sharing data between main app, keyboard extension, share extension |
| `com.apple.developer.icloud-services` | `[CloudKit]` | CloudKit private database for sync |
| `com.apple.developer.icloud-container-identifiers` | `iCloud.com.projectv.notes` | CloudKit container identity |
| `com.apple.security.temporary-exception.accessibility` | `true` (macOS only) | Required for `AXUIElement` text injection; reviewed annually |
| `com.apple.developer.aps-environment` | `production` (release) / `development` (debug) | CloudKit push notifications for sync |

No entitlements are present that are not listed above. The accessibility temporary exception is documented in the App Review notes and in the GitHub repository's security documentation, explaining precisely which AX APIs are used and why.

---

# Section 13: Testing Strategy

## 13.1 Unit Testing

All unit tests live in the `VoiceInputCoreTests` Swift package test target. Tests are written using Swift Testing framework (introduced in Xcode 16) alongside XCTest for compatibility.

**Speech Engine:**
- `MockSpeechEngine` conforms to `SpeechEngineProtocol` and returns pre-recorded `SpeechAnalyzerResult` fixtures from JSON files in the test bundle
- Test cases cover: empty audio, single word, long dictation (2000+ word fixture), non-English input, mixed-language input, high-noise fixture (low confidence scores)
- `SpeechEngineProtocol` conformance tests verify that any concrete implementation handles the full `AsyncStream<SpeechResult>` lifecycle correctly

**Note Store:**
- CRUD tests for `Note`, `Folder`, `Tag` covering all lifecycle operations
- Soft delete and tombstone behavior
- Smart folder predicate evaluation (Today, Untagged, Dictated Today)
- Search query tests: exact match, prefix match, multi-term, tag filter, date range filter
- Concurrency tests: simultaneous read/write from multiple `ModelContext` actors

**AI Provider:**
- `MockAIProvider` conforms to `AIProviderProtocol` returning canned responses
- Conformance test suite verifies any concrete provider implementation correctly: handles empty input, handles rate limit errors (429), handles malformed response, respects cancellation token
- Filler removal tests with known filler-word fixtures
- Punctuation restoration accuracy tests against ground truth corpus

**Search Index:**
- Full-text search accuracy tests: tests index with 1000 synthetic notes, queries for rare and common terms, verifies recall ≥ 95% and precision ≥ 90% for test corpus
- Index rebuild performance test: 10,000 notes indexed in < 5 seconds on target hardware

**Coverage Target:** Minimum 80% line coverage for `VoiceInputCore` package, enforced by Codecov check in CI that fails PRs below threshold.

---

## 13.2 Integration Testing

Integration tests run in the `VoiceInputIntegrationTests` target, which requires entitlements and may run against live system services in controlled environments.

**CloudKit Sync Round-Trip:**
- Uses CloudKit Development environment with a dedicated test container (`iCloud.com.projectv.testing`)
- Test flow: create note on device A simulator → wait for sync (polling with timeout 30s) → verify note appears in device B simulator with correct field values
- Conflict resolution test: modify same note field on two simulators simultaneously, verify winning version selected and conflict copy created
- Soft delete propagation: delete on one device, verify tombstone sync and deletion on second device within timeout

**Accessibility API Injection Verification (macOS):**
- Integration test launches a test harness app (`TextInjectionTestApp`) with a known text field
- `AXTextInjector` targets the test app's text field
- Verifies injected text matches expected string exactly
- Tests append mode, replace mode, and cursor position preservation
- Tests injection into `NSTextField`, `NSTextView`, and WebKit `WKWebView` separately

**AI Provider End-to-End (Mock Servers):**
- `MockAIServer` is a minimal HTTP server (built with `NIOCore` or simple `URLSession`-based server) that simulates OpenAI and Anthropic API endpoints
- Tests exercise the full request/response pipeline: text → `AIRequest` → HTTP → `MockAIServer` → `AIResponse` → processed text
- Error scenario tests: 401 unauthorized, 429 rate limit with Retry-After header, 500 server error, network timeout, malformed JSON response

**Sync Conflict Resolution:**
- Deterministic conflict generation using controlled `ModelContext` modification timestamps
- Verifies all three conflict outcomes: local wins, remote wins, both preserved as copies

---

## 13.3 UI Testing

**XCUITest Suite:**
Critical user flows covered by XCUITest automation:

| Flow | Steps Covered |
|---|---|
| Onboarding | Launch → grant mic permission (mocked) → set hotkey → skip AI → tutorial → complete |
| Create and edit note | New note → type title → dictate body (mock engine) → verify text inserted → close |
| Search | Open library → type search query → verify filtered results → clear search → verify all notes |
| Tag management | Open note → add tag → verify tag appears → remove tag → verify removed |
| Export | Select note → export as Markdown → verify file in Downloads (mocked sandbox) |
| Settings round-trip | Open Settings → change hotkey → close → verify new hotkey registered |
| AI provider setup | Settings → AI Providers → Add OpenAI → enter key → Test Connection (mock) → Save |

**SwiftUI Preview Coverage:**
Every `View` file in the project has at least one `#Preview` macro block. The CI lint check verifies preview presence using a custom script that scans for `struct.*View` definitions lacking a corresponding `#Preview`. Previews cover: default state, empty state, error state, Dynamic Type `.accessibilityExtraExtraExtraLarge`, Dark Mode, and High Contrast where applicable.

**Snapshot Testing:**
`swift-snapshot-testing` library is used for visual regression. Snapshots are recorded at first run and committed to the repository. CI compares snapshots on every PR; pixel-level diffs fail the build. Snapshots are taken at 1x and 2x scale for macOS, and for iPhone 16 Pro and iPad Pro 13" form factors on iOS.

**Automated Accessibility Audit:**
Each XCUITest flow includes a call to `app.performAccessibilityAudit()` (Xcode 15+) at key points in the flow. Violations cause test failure. Audit categories enabled: `.contrast`, `.hitRegion`, `.sufficientElementDescription`, `.dynamicType`.

---

## 13.4 Performance Testing

Performance tests use `XCTestCase.measure` blocks and `XCTMetric` to enforce budget constraints. All benchmarks are measured on a MacBook Pro M1 (baseline hardware) and iPhone 15 (baseline iOS device).

| Benchmark | Target | Test Method |
|---|---|---|
| Dictation activation latency | < 100ms from hotkey to first character emitted | `XCTClockMetric`, 10 iterations |
| First transcription result | < 250ms from audio start to first `SpeechResult` | Custom metric, 20 iterations |
| Note search (10,000 notes) | < 200ms end-to-end | `XCTClockMetric`, 50 iterations |
| App cold launch (macOS) | < 1.0s to first interactive frame | `XCTApplicationLaunchMetric` |
| App cold launch (iOS) | < 1.0s to first interactive frame | `XCTApplicationLaunchMetric` |
| Memory during long dictation (5 min) | < 150 MB peak RSS | `XCTMemoryMetric` |
| Memory for 10,000 note library | < 100 MB peak RSS | `XCTMemoryMetric` |
| CloudKit sync (100 notes) | < 5s to sync complete | Custom async metric with timeout |
| Note editor scroll (10,000 word note) | 60 fps maintained | `XCTOSSignpostMetric` |

Performance test failures (> 20% regression vs. baseline) block PR merges via CI. Baselines are stored in `.xctestplan` baseline files committed to the repository and updated manually when intentional performance changes are made.

---

## 13.5 Security Testing

**Audio Buffer Lifecycle Verification:**
A custom test harness instruments `SpeechEngineProtocol.startSession()` to track all `AVAudioPCMBuffer` allocations. After session end, the test uses `Instruments` Allocations template (run via `xctrace`) in CI to verify no audio buffer memory persists beyond the session boundary. An in-process test uses a mock allocator to verify `memset` zeroing is called on every buffer.

**Keychain Storage Audit:**
A test reads the Keychain after an AI provider API key is stored and verifies: accessibility is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, synchronizable is `false`, the key data matches what was stored, no other unexpected items are present in the app's Keychain access group.

**Network Traffic Analysis:**
The CI network test spins up a `URLProtocol` interceptor that logs all outbound HTTP requests during a scripted app session (onboarding + dictation + note creation + sync). The test asserts that the set of destination hosts matches exactly the allowlist: `{api.openai.com, api.anthropic.com, cloudkit.apple.com, *.icloud.com, localhost}`. Any unexpected host causes test failure.

**Sandbox Escape Testing:**
A set of tests attempts to access paths outside the sandbox (e.g., `~/Documents`, `/tmp`, `/private/var`) directly via `FileManager`. All such attempts should throw `NSCocoaErrorDomain` Code 513 (operation not permitted). These tests verify the sandbox configuration is correctly scoped.

---

# Section 14: CI/CD & Build

## 14.1 Build System

### Xcode Project Structure

```
VoiceInput.xcworkspace
├── VoiceInput.xcodeproj
│   ├── Targets
│   │   ├── VoiceInput (macOS app)
│   │   ├── VoiceInputMenuBarHelper (macOS helper, XPC service)
│   │   ├── VoiceInputiOS (iOS app)
│   │   ├── VoiceInputKeyboardExtension (iOS keyboard extension)
│   │   ├── VoiceInputShareExtension (iOS share extension)
│   │   ├── VoiceInputWidgets (iOS WidgetKit extension)
│   │   ├── VoiceInputCoreTests (unit tests)
│   │   ├── VoiceInputIntegrationTests (integration tests)
│   │   └── VoiceInputUITests (XCUITest suite)
│   └── Configurations
│       ├── Debug.xcconfig
│       ├── Release.xcconfig
│       └── Beta.xcconfig
└── Packages
    ├── VoiceInputCore (Package.swift)
    └── VoiceInputUI (Package.swift)
```

### Build Configurations

| Configuration | Optimizations | Assertions | Logging | Code Signing |
|---|---|---|---|---|
| Debug | None (`-Onone`) | Enabled | Verbose (OSLog debug) | Development cert |
| Beta | Basic (`-O`) | Disabled | Info level | Distribution cert, TestFlight |
| Release | Full (`-O`) | Disabled | Warnings/errors only | Distribution cert, App Store / Notarized |

### Swift Package Manager Dependencies

All dependencies are managed via SPM. Third-party dependencies are minimized:

| Package | Purpose | Version Strategy |
|---|---|---|
| `apple/swift-algorithms` | Collection utilities | Up-to-next-major |
| `apple/swift-async-algorithms` | Async stream utilities | Up-to-next-major |
| `nicklockwood/SwiftFormat` | Code formatting (dev only) | Exact version pin |
| `realm/SwiftLint` | Linting (dev only) | Exact version pin |
| `pointfreeco/swift-snapshot-testing` | Snapshot tests (test only) | Up-to-next-major |
| `sparkle-project/Sparkle` | Auto-update (macOS direct dist) | Up-to-next-major |

No networking libraries (Alamofire, etc.) are used; `URLSession` async/await APIs are used directly.

---

## 14.2 CI Pipeline (GitHub Actions)

### PR Checks (runs on every pull request)

```yaml
# .github/workflows/pr.yml
jobs:
  lint:        # SwiftLint + SwiftFormat --lint (fail on violations)
  build-macos: # xcodebuild build, scheme VoiceInput, destination macOS
  build-ios:   # xcodebuild build, scheme VoiceInputiOS, destination iOS Simulator
  unit-tests:  # xcodebuild test, VoiceInputCoreTests, both platforms
  ui-tests:    # xcodebuild test, VoiceInputUITests, iPhone 16 Pro Simulator
  coverage:    # Codecov upload; fail if <80% coverage on VoiceInputCore
  snapshot:    # swift-snapshot-testing comparison; fail on diff
```

### Nightly Build (runs on schedule, 02:00 UTC)

```yaml
# .github/workflows/nightly.yml
jobs:
  full-integration-tests:  # CloudKit dev environment, mock AI servers, full suite
  performance-tests:       # XCTMetric benchmarks; post results to PR comment
  security-scan:           # Network traffic audit, Keychain audit, buffer lifecycle
  dependency-audit:        # Check for SPM package updates, flag major version bumps
```

### Release Pipeline (runs on `release/*` branch push or manual trigger)

```yaml
# .github/workflows/release.yml
jobs:
  build-and-sign:    # Xcode Cloud triggered via API; builds all targets, signs
  notarize:          # macOS app notarized via notarytool in Xcode Cloud
  create-dmg:        # Creates .dmg with create-dmg tool, staples notarization
  github-release:    # Creates GitHub Release with .dmg, release notes from CHANGELOG
  homebrew-update:   # Opens automated PR in projectv/homebrew-tap with new version hash
  testflight:        # iOS .ipa submitted to TestFlight via Xcode Cloud
```

Xcode Cloud handles all code signing via its managed signing capability. No certificates or private keys are stored in GitHub secrets.

---

## 14.3 Distribution

### Primary Distribution: Unlisted App Store

Murmur is distributed as an **unlisted App Store listing** — the app is not visible in App Store search results and can only be installed via a direct link shared with employees. This is the recommended Apple distribution method for small internal teams that do not require MDM or Apple Business Manager.

- **Target audience:** 2–10 employees at Unconventional Psychotherapy
- **Apple Developer account:** Standard Apple Developer Program ($99/yr) — no Enterprise Program required
- **No MDM or Apple Business Manager required** — employees install via direct link on their personal or company devices
- **App subtitle/tagline:** "by Unconventional Psychotherapy"
- **Access control:** Direct link shared internally; no public discoverability
- **Both macOS and iOS** apps are distributed as unlisted listings from the same App Store Connect account

### macOS Distribution Channels

| Channel | Artifact | Update Mechanism | Audience |
|---|---|---|---|
| Unlisted App Store | App Store listing (unlisted) | App Store auto-update | Employees (primary) |
| GitHub Releases | Notarized `.dmg` | Sparkle (in-app) | Open-source contributors, developers |
| Homebrew Cask | `brew install --cask murmur` | `brew upgrade` | CLI-comfortable contributors |

The **Unlisted App Store** is the primary distribution channel for employees. GitHub Releases remain available for open-source contributors building from source.

### iOS Distribution

| Channel | Mechanism | Audience |
|---|---|---|
| TestFlight | Xcode Cloud → TestFlight | Internal testing before release |
| Unlisted App Store | Xcode Cloud → App Store Connect (unlisted) | Employees (primary) |

### Release Channels

| Channel | Branch | Cadence | Update Channel in App |
|---|---|---|---|
| Stable | `main` | As needed (feature complete) | Stable (default) |
| Beta | `develop` | Weekly if changes exist | Beta (TestFlight) |

For a team of 2–10 users, nightly builds are unnecessary. Beta releases are distributed via TestFlight; stable releases via the unlisted App Store listing.

### Auto-Update

The unlisted App Store listing handles auto-updates via the standard App Store update mechanism. For the direct-distribution macOS build (GitHub Releases), Sparkle 2.x is integrated. The appcast XML is hosted on GitHub Pages. Appcast entries are generated by the release GitHub Action. Updates are Ed25519-signed (Sparkle's `generate_keys` / `sign_update` tools).

---

## 14.4 Code Quality

### SwiftLint Configuration

`.swiftlint.yml` enforces:
- All default rules enabled
- Explicitly enabled: `force_unwrapping` (error), `implicitly_unwrapped_optional` (warning), `todo` (warning), `unowned_variable_capture` (error), `empty_count` (error)
- Explicitly disabled: `file_length` (managed by SwiftFormat file organization rules), `type_body_length` (not enforced for large view structs)
- Custom rules: ban `print()` statements in non-debug targets; require `// MARK:` section headers in files >100 lines

### SwiftFormat Configuration

`.swiftformat` enforces consistent style: trailing commas, sorted imports, consistent spacing, 4-space indentation, opening braces on same line. Format is verified (not auto-applied) in CI; developers are expected to run `swiftformat .` locally before committing (enforced by a pre-commit hook in `.git-hooks/pre-commit`).

### Branch Strategy

```
main          ← stable releases only; direct push blocked; requires PR + 1 approval
  └── develop ← integration branch; nightly builds; requires PR + 1 approval
        └── feature/[name]  ← feature work; freely pushable by author
        └── fix/[name]      ← bug fixes
        └── chore/[name]    ← non-functional changes
```

All PRs targeting `develop` or `main` require:
- At least 1 approving review from a codeowner
- All CI checks passing
- No unresolved review comments
- Linear history preferred (rebase merge); squash allowed for small fixes

---

# Section 15: Roadmap & Phasing

## Phase 1: Foundation (Months 1–3)

**Goal:** A working, installable macOS app that delivers the core value proposition: voice dictation into any text field with personal dictionary support.

**Deliverables:**
- `SpeechAnalyzer`-powered dictation engine (on-device, Apple Silicon)
- Text injection via Accessibility API (`AXUIElement`) and clipboard fallback
- Menu bar app with popover: start/stop dictation, status indicator, open library
- Basic notes: create new note, list notes, view note, delete note; no folders, tags, or rich editing yet — plain Markdown only
- Clinical Mode toggle (default ON for Unconventional Psychotherapy deployment): disables all cloud AI; on-device only
- Personal dictionary: manually add/remove words; applied to `SpeechAnalyzer` custom vocabulary
- Global hotkey registration (default `⌘⇧Space`)
- Dictation HUD with waveform and live preview
- Onboarding flow covering microphone and accessibility permissions
- Settings: General (hotkey, language, appearance), About
- Local-only storage (no sync)
- macOS 26.0+ only; no iOS

**Success Criteria:**
- Dictation works in Safari, Mail, Notes, VS Code, and Xcode (covering NSTextView, WebKit, and Electron text fields)
- Latency from hotkey press to first character < 200ms on M1 MacBook Pro (Phase 1 target; tightens to 100ms in Phase 2)
- App runs fully offline
- Basic onboarding completes without crashes

---

## Phase 2: Intelligence (Months 4–6)

**Goal:** Add the AI-powered editing pipeline, complete the notes system, and reach feature parity with basic Wispr Flow functionality.

**Deliverables:**
- Pluggable AI provider architecture (`AIProviderProtocol`)
- First providers: Apple Intelligence (via Writing Tools integration) and OpenAI (GPT-4o)
- Post-processing pipeline: filler word removal, grammar correction, punctuation restoration, sentence formatting
- Command mode: text editing commands only ("delete that", "new line", "capitalize that", "undo", "select all", "scratch that"); app navigation commands deferred to Phase 4+
- Snippet library with trigger → expansion and system tokens (`$DATE$`, `$TIME$`, `$CLIPBOARD$`)
- Full notes system: folder hierarchy, tag management, Markdown editor with live preview (split view, inline preview, source only, preview only modes), full-text search via FTS5
- Export: Markdown, plain text, PDF (via `PDFKit`)
- Settings: AI Providers panel, Dictionary & Snippets panel, Notes panel, AI Usage & Cost tracking
- Dictation mode switching (Append / Replace / Command) from HUD
- Latency target tightens to < 100ms hotkey to first character

**Success Criteria:**
- AI post-processing improves transcription quality (measured by user study with 5 beta users)
- Command mode handles 10 basic commands reliably (>90% success rate)
- Notes full-text search returns results in < 200ms for a 1,000-note library
- App passes initial accessibility audit (VoiceOver, Dynamic Type, keyboard navigation)

---

## Phase 3: Polish & iOS (Months 7–9)

**Goal:** Expand to iOS, add iCloud sync, and add the power-user features that differentiate Murmur from simpler dictation tools.

**Deliverables:**
- iOS companion app (tab bar layout: Notes, Dictate, Search, Settings)
- iOS keyboard extension for system-wide dictation
- Share extension (iOS)
- WidgetKit widgets: Quick Dictate and Recent Notes
- iCloud + CloudKit sync (private database; conflict resolution)
- Whisper mode (low-volume sensitive dictation)
- Code syntax awareness: when active app is a code editor, apply code-mode vocabulary and formatting rules
- Note templates (pre-defined structures: Meeting Notes, Daily Journal, etc.)
- Smart folders (Untagged, This Week, Dictated Today)
- App profiles: per-app dictation mode and AI pipeline overrides
- Additional AI providers: Ollama (local LLM) and Anthropic Claude
- Full Settings panel completion: App Profiles, Privacy
- Accessibility: full audit, all VoiceOver rotors, Dynamic Type at all sizes, Reduce Motion compliance

**Success Criteria:**
- iOS app approved and on TestFlight
- CloudKit sync round-trip < 5 seconds for a 100-note change set
- Accessibility audit scores "Pass" on all XCUITest accessibility audit categories
- App profiles correctly override behavior in at least 5 tested apps

---

## Phase 4: Refinement & Open Source (Months 10–12)

**Goal:** Stabilize the internal deployment, gather employee feedback, and prepare the open-source repository for public visibility.

**Deliverables:**
- Shared snippet/dictionary packs for the team (exportable bundles for onboarding new employees)
- Speaker diarization: attribute segments of a multi-speaker recording to individual speakers (requires on-device model)
- Advanced command mode: app navigation commands and complex editing ("move this paragraph up", "change the heading to…", "summarize this note")
- Optional WYSIWYG rich text editing mode (upgrade from Markdown editor)
- Bear and Obsidian vault import
- Accessibility audit (VoiceOver, Dynamic Type, keyboard navigation)
- Open-source repository preparation: CONTRIBUTING.md, code of conduct, issue templates, PR templates, LICENSE
- Public API documentation generated with DocC and hosted on GitHub Pages
- Localization infrastructure: all strings in `.xcstrings`; initial translations for Spanish, French, German, Japanese

**Success Criteria:**
- All employees report satisfaction score of 4/5 or higher
- Internal feedback backlog triaged and top 5 issues resolved
- Open-source repository is public with clear documentation for external contributors
- Accessibility audit passes on all XCUITest accessibility audit categories

---

## Phase 5: Ecosystem (Year 2+)

**Goal:** Extend Murmur beyond its core internal use case and explore platform capabilities as the open-source community grows.

**Potential Deliverables (subject to team needs and community interest):**
- **Plugin/extension system**: documented Swift API for third-party plugins; sandboxed plugin execution; plugin discovery via GitHub topic
- **Meeting recording mode**: long-form multi-speaker recording with diarization, chapter generation, action item extraction
- **Shortcuts.app integration**: custom Shortcuts actions for dictate, search, export, summarize
- **Collaboration features**: shared note folders via CloudKit shared databases; real-time co-editing (ambitious; requires careful conflict resolution design)
- **iPadOS optimization**: Stage Manager support, Apple Pencil annotation on notes, full keyboard/trackpad support
- **visionOS port**: spatial notes interface; voice dictation in immersive environment; investigate feasibility with new `SpeechAnalyzer` visionOS support
- **Advanced AI features**: multi-note summarization, conversation-with-notes RAG interface, automatic meeting minutes generation
- **Enterprise considerations**: MDM deployment profile, enterprise SSO for AI providers, admin-managed settings

Phase 5 features are intentionally not time-boxed; they will be prioritized by internal team needs and, secondarily, by community interest and contributions.

---

# Section 16: Appendices

## Appendix A: Wispr Flow Feature Parity Checklist

| Wispr Flow Feature | Status in Murmur | Murmur Equivalent / Notes |
|---|---|---|
| System-wide voice dictation | Included | `AXTextInjector` + clipboard fallback; keyboard extension on iOS |
| Push-to-talk activation | Included | Configurable in Settings > General; `CGEventTap` hotkey |
| Toggle activation mode | Included | Toggle mode alongside push-to-talk |
| Menu bar quick access | Included | `NSStatusItem` popover with full controls |
| Real-time waveform display | Included | Dictation HUD with `AVAudioPCMBuffer` amplitude visualization |
| Live transcript preview | Included | Partial-result streaming from `SpeechAnalyzer` shown in HUD |
| AI grammar correction | Included | Post-processing pipeline; OpenAI, Claude, Apple Intelligence backends |
| Filler word removal | Included | AI pipeline stage; configurable per-provider |
| Automatic punctuation | Included | AI pipeline stage |
| Custom vocabulary / dictionary | Included | Personal Dictionary in Settings; applied to `SpeechAnalyzer` |
| Text snippet expansion | Included | Snippet library with trigger → expansion |
| Per-app behavior profiles | Included (Phase 3) | App Profiles in Settings |
| Whisper mode (quiet dictation) | Included (Phase 3) | Low-gain capture mode with `SpeechAnalyzer` sensitivity tuning |
| Command mode | Included (Phase 2) | Text editing commands in Phase 2; app navigation in Phase 4+ |
| Multiple language support | Included | Language picker; `SpeechAnalyzer` language configuration |
| Code mode (developer-friendly) | Included (Phase 3) | Syntax-aware vocabulary when dictating into code editors |
| Notes library | Included | Full notes app with folders, tags, Markdown editor with live preview, FTS5 search |
| iCloud sync | Included (Phase 3) | CloudKit private database sync |
| Export (Markdown, PDF) | Included (Phase 2) | Export sheet: Markdown, plain text, PDF |
| iOS companion app | Included (Phase 3) | Full iOS app with keyboard extension |
| Dark mode | Included | Full light/dark mode support |
| Keyboard shortcuts | Included | Comprehensive shortcut table; all configurable |
| Onboarding flow | Included | 4-step first-launch flow (Welcome → Mic → Accessibility → All Set) |
| AI provider selection | Included | Pluggable provider architecture; OpenAI, Claude, Apple, Ollama |
| Automatic AI model selection | Planned | AI provider priority ordering with fallback; smart selection in Phase 4 |
| Meeting recording mode | Planned (Phase 5) | Long-form recording with diarization |
| Speaker diarization | Planned (Phase 4) | On-device multi-speaker attribution |
| Windows / Linux support | Out of Scope | macOS and iOS only; Swift/SwiftUI architecture precludes cross-platform |
| Browser extension | Out of Scope | Accessibility API injection covers browser text fields without an extension |
| Android support | Out of Scope | Native Apple platforms only |
| Standalone offline AI model | Included | Ollama provider (Phase 3) enables fully local AI post-processing |
| Sharing/collaboration | Planned (Phase 5) | CloudKit shared databases for collaborative notes |
| Shortcuts.app integration | Planned (Phase 5) | Custom Shortcuts actions for all major operations |
| Enterprise MDM support | Planned (Phase 5) | Managed app configuration via MDM |
| Telemetry / analytics | Out of Scope (default off) | Optional anonymous analytics only; zero telemetry by default |

---

## Appendix B: Glossary of Terms

**AXUIElement** — An opaque reference type in macOS's Accessibility framework (`ApplicationServices.framework`) that represents any UI element of any running application. Murmur uses `AXUIElement` APIs to locate the focused text field and inject transcribed text directly into other applications.

**AVAudioEngine** — Apple's high-performance audio processing graph API. Murmur uses `AVAudioEngine` to capture microphone input as a stream of `AVAudioPCMBuffer` objects for processing by `SpeechAnalyzer`.

**AVAudioPCMBuffer** — A buffer of audio samples in PCM format produced by `AVAudioEngine`. Each buffer represents a short window of audio data (typically 50–100ms). Murmur zeros these buffers after transcription to prevent audio data from persisting in memory.

**CloudKit** — Apple's cloud database framework enabling private per-user data storage, public shared data, and cross-device sync. Murmur uses CloudKit private database for note synchronization.

**CKRecord** — The fundamental unit of data storage in CloudKit. Each `Note`, `Folder`, and `Tag` in Murmur is serialized to a `CKRecord` for CloudKit sync.

**CGEventTap** — A macOS API for intercepting and monitoring system-level keyboard and mouse events. Murmur uses `CGEventTap` in the menu bar helper process to capture the global dictation hotkey regardless of which application is frontmost.

**Dynamic Type** — Apple's system feature that allows users to set a preferred reading size. Text using Dynamic Type semantic styles (`.body`, `.headline`, etc.) scales proportionally to this preference, including extra-large accessibility sizes.

**HUD (Heads-Up Display)** — The floating translucent overlay panel that appears during active dictation, showing the waveform, live transcript, and controls. Implemented as a floating `NSWindow` / `UIViewController` overlay.

**iCloud Drive** — Apple's file-based cloud storage. Used as a fallback storage location for note exports and attachments in Murmur.

**NSStatusItem** — The macOS API object representing an item in the menu bar (the strip of icons at the top right of the screen). Murmur's menu bar helper creates an `NSStatusItem` to display the app icon and present the popover.

**Ollama** — An open-source tool for running large language models locally on consumer hardware. Murmur supports Ollama as a local AI backend, enabling fully offline AI post-processing without any cloud API calls.

**SpeechAnalyzer** — A new Apple framework introduced in macOS 26 / iOS 19 providing on-device, Apple Silicon-optimized speech recognition with streaming results, custom vocabulary, and speaker confidence scores. This is the core transcription engine for Murmur.

**SwiftData** — Apple's Swift-native persistence framework (introduced WWDC 2023) providing `@Model` macro-based ORM over a Core Data stack. Murmur uses SwiftData for local note storage.

**TextInjection / Text Injection** — The process of programmatically inserting transcribed text into a text field in another application. Murmur uses two methods: `AXUIElement` accessibility API (primary, macOS) and clipboard-paste simulation (fallback).

**VAD (Voice Activity Detection)** — The algorithmic process of determining whether audio input contains human speech or background noise/silence. `SpeechAnalyzer` provides built-in VAD; Murmur uses it to automatically detect the start and end of speech for auto-stop dictation mode.

**VoiceOver** — Apple's built-in screen reader for macOS and iOS. VoiceOver reads aloud the names, values, and hints of UI elements, enabling users with visual impairments to use the application fully.

**WebKit** — Apple's web rendering engine used by Safari and many Electron-based apps. Text injection into WebKit text fields requires a different `AXUIElement` strategy than native `NSTextView` fields.

**WidgetKit** — Apple's framework for building home screen and lock screen widgets on iOS and macOS. Murmur uses WidgetKit for the Quick Dictate and Recent Notes widgets.

**XPC (Cross-Process Communication)** — Apple's secure inter-process communication mechanism. Murmur uses XPC for communication between the macOS main app and the menu bar helper process.

---

## Appendix C: Reference Links

**Apple Platform Documentation:**

- Apple SpeechAnalyzer framework documentation: `https://developer.apple.com/documentation/speechanalyzer` *(available post-WWDC 2025)*
- Apple Accessibility API (macOS AXUIElement): `https://developer.apple.com/documentation/applicationservices/axuielement`
- Apple Accessibility (iOS UIAccessibility): `https://developer.apple.com/documentation/uikit/uiaccessibility`
- CloudKit documentation: `https://developer.apple.com/documentation/cloudkit`
- CloudKit `encryptedValues` (end-to-end encryption): `https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues`
- SwiftData documentation: `https://developer.apple.com/documentation/swiftdata`
- WidgetKit documentation: `https://developer.apple.com/documentation/widgetkit`
- AVAudioEngine documentation: `https://developer.apple.com/documentation/avfaudio/avaudioengine`
- App Sandbox entitlements reference: `https://developer.apple.com/documentation/bundleresources/entitlements`
- Notarizing macOS software: `https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution`
- Data Protection API: `https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files`
- `SMAppService` (Login Items): `https://developer.apple.com/documentation/servicemanagement/smappservice`

**AI Provider APIs:**

- OpenAI API documentation: `https://platform.openai.com/docs`
- Anthropic Claude API documentation: `https://docs.anthropic.com/en/api`
- Ollama documentation and API reference: `https://github.com/ollama/ollama/blob/main/docs/api.md`
- Apple Intelligence / Writing Tools developer documentation: `https://developer.apple.com/documentation/uikit/nswritingtoolscoordinator`

**Relevant WWDC Sessions:**

- WWDC 2025 — "Introducing SpeechAnalyzer" *(session number TBD)*
- WWDC 2025 — "What's new in Swift" *(session number TBD)*
- WWDC 2023 — "Meet SwiftData" (Session 10187)
- WWDC 2023 — "Sync to iCloud with CKSyncEngine" (Session 10188)
- WWDC 2024 — "Bring your app's core features to users with App Intents" (Session 10210)
- WWDC 2024 — "Unlock the power of places in MapKit" — referenced for custom overlay technique applicable to HUD window
- WWDC 2023 — "Build accessible apps with SwiftUI and UIKit" (Session 10036)
- WWDC 2022 — "Meet Transferable" (Session 10059) — relevant to Share extension design

**Third-Party References:**

- Sparkle auto-update framework: `https://sparkle-project.org`
- SwiftLint: `https://github.com/realm/SwiftLint`
- SwiftFormat: `https://github.com/nicklockwood/SwiftFormat`
- swift-snapshot-testing: `https://github.com/pointfreeco/swift-snapshot-testing`
- Wispr Flow (competitive reference): `https://wisprflow.ai`
- WCAG 2.1 AA Guidelines: `https://www.w3.org/TR/WCAG21/`

---

## Appendix D: Open Questions

The following questions are unresolved and must be addressed by the development team during implementation planning. Decisions should be documented as Architecture Decision Records (ADRs) in the repository at `docs/adr/`.

1. **SpeechAnalyzer API Availability and Stability:** `SpeechAnalyzer` was announced at WWDC 2025 but may have API-breaking changes in final macOS 26 / iOS 19 releases. What is the team's strategy if the API surface changes significantly between beta and GM? Is a fallback to `SFSpeechRecognizer` acceptable for Phase 1 if `SpeechAnalyzer` is not yet suitable for production?

2. **Accessibility Temporary Exception Renewal:** The `com.apple.security.temporary-exception.accessibility` entitlement requires periodic review and justification for App Store distribution. Has the team confirmed this entitlement will be granted for the App Store build? Is there an `AXUIElement`-free text injection strategy (e.g., using `NSTextInputContext` or `UITextInputDelegate` APIs on the target app side) that could eliminate the need for this entitlement?

3. **CloudKit CKSyncEngine vs. Manual Sync:** ✅ **Resolved.** Murmur adopts `CKSyncEngine` (available macOS 14+/iOS 17+, well within macOS 26+ floor). Field-level conflict resolution is implemented within `CKSyncEngine`'s delegate callbacks. The custom `SyncOperationQueue` model was removed — `CKSyncEngine` manages its own pending changes queue. See Section 6.2 Layer 4 and Section 7.3.

4. **AI Post-Processing Latency Budget:** The end-to-end dictation latency target is < 100ms hotkey to first character. If AI post-processing is synchronous (text not injected until AI completes), this target will be missed for cloud providers (OpenAI/Claude round-trips are typically 300–800ms). The team must decide between: (a) inject raw transcript immediately and then apply AI edits as a diff, which requires a diff-and-replace text injection mechanism; or (b) make AI post-processing explicitly asynchronous and visible to the user. What is the preferred UX model?

5. **Personal Dictionary Size and Performance:** `SpeechAnalyzer`'s custom vocabulary API has an undocumented maximum entry count. What is the practical limit on personal dictionary size? If a user imports a large word list (e.g., 10,000 medical terms), will `SpeechAnalyzer` performance degrade? Is there a tiered approach (hot dictionary vs. cold dictionary) that should be designed upfront?

6. **macOS Menu Bar Helper as Login Item:** ✅ **Resolved.** The XPC protocol contract (`MurmurXPCProtocol`) is defined in Section 6.2 Layer 6. `SpeechAnalyzer` runs in the main app process; the helper captures audio via `AVAudioEngine` and forwards buffers to the main app via XPC. The helper is a fully sandboxed XPC service. Behavior when the main app is not running: the helper queues the start request and launches the main app in background.

7. **iOS Keyboard Extension Memory Limit:** ✅ **Resolved.** The keyboard extension captures audio and streams it to the main app via App Group shared memory / local socket. `SpeechAnalyzer` runs exclusively in the main app process, keeping the extension well within the ~120 MB memory cap. The extension calls `insertText(_:)` with transcription results received from the main app. See Section 9.6 and Section 10.2.

8. **App Store Reviewer Concerns for Accessibility Entitlement:** Apple's App Review team scrutinizes apps that request Accessibility access. The submission must include a detailed justification. The team should prepare App Review notes proactively and consider whether to pursue a direct distribution-only strategy for the first release to avoid App Review delays during initial development cycles.

9. **Snippet Expansion Token Security:** The `$CLIPBOARD$` token in snippets reads from the system clipboard at expansion time. On macOS 14+, accessing the clipboard from a sandboxed app triggers a permission dialog on first access in some contexts. What is the UX for this permission request, and is there a way to pre-authorize clipboard access to avoid mid-dictation interruption?

10. **Open Source Licensing and AI Provider API Keys:** The project is open source. If a user builds from source and distributes a fork with their own embedded OpenAI API key, this creates financial and terms-of-service risks. Should API keys be strictly user-supplied (no embedded keys ever), and should the build system enforce this via a CI check that scans for hardcoded key patterns? This policy should be documented in CONTRIBUTING.md before any external contributors are invited.

---

*End of Sections 9–16.*

*Document version: 0.1-draft. All specifications subject to revision based on SpeechAnalyzer GM API availability, App Review feedback, and community input during Phase 1 development.*

---

