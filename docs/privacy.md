# Privacy and network behavior

## Default principle

Vault notes are private data. Local file operations should remain local unless the user explicitly invokes a feature that requires an external provider. API credentials must be supplied outside the repository and must never be committed.

## Data-flow overview

| Feature | Network | Potential receiver | Potential data sent | Control |
|---|---:|---|---|---|
| Local capture, task, project, review, search | Usually no | None | Local paths and note content remain on device | Do not enable external integrations |
| Link AI triage | Yes when invoked/configured | Anthropic | Note name, wikilink, and a limited context excerpt | Do not configure or run the AI triage path |
| NotebookLM-style grounded research | Yes | Google Gemini/File Search | Topic, selected Vault sources, prompts | Do not configure `GEMINI_API_KEY` or invoke the feature |
| YouTube extraction/summarization | Yes | YouTube/Google and selected model provider | Video URL, transcript or prompt context | Use transcript-only/local processing where possible |
| Podcast processing | Yes | Podcast host and possibly OpenAI Whisper | URL/network metadata and downloaded audio | Do not invoke remote transcription; use an approved local alternative |
| Web/deep research | Yes | Provider configured by the user, including possible Perplexity, xAI, Gemini, Tavily, or Brave paths | Search query, prompt, and selected context | Provider allowlist; omit credentials for disabled providers |
| X reading/pulse | Yes | xAI/X-related search endpoints | Post URL, query, prompt context | Do not configure or invoke the feature |

## Existing controls

The installed code includes controls such as URL validation, redirect re-validation, download size limits for podcast audio, and rules that treat external instruction-shaped text as untrusted data. These controls reduce risk but do not replace informed consent and data minimization.

## Repository hygiene

Before every public push:

1. run `verify.ps1`;
2. inspect `git status --short --ignored`;
3. inspect `git diff --cached --name-status`;
4. confirm no `.env`, Vault note, log, screenshot, recording, or provider response is staged;
5. use GitHub secret scanning or another independent credential scanner.

## Known instance information

The included `_CLAUDE.md` intentionally contains the Vault identity and the local example path `D:\Cosmic Mindsea`, because this repository represents the real Cosmic Mindsea instance rules. It does not include API credentials or private knowledge-note bodies.

