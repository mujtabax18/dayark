The source catalogue is `dayark_model_catalog.csv`. Run
`python3 tool/ai/generate_catalogue.py` from the repository root after editing it.
The generated Dart file is bundled with the application; browsing is unnecessary
at runtime to sort models.

`family_release_date` is the family's first public launch or announcement, not
the release of every model size or community GGUF quantization. It is repeated
across the family's rows so its launch date stays consistent.
`family_release_source_url` retains the evidence. Dates were checked online on
2026-11-18.

| Family | Launch date | Evidence |
| --- | --- | --- |
| Gemma 4 | 2026-04-02 | [Google launch announcement](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) |
| Qwen3.5 | 2026-02-16 | [Qwen official release history](https://github.com/QwenLM/Qwen3.8#news) |
| LFM2.5 | 2026-01-05 | [Liquid AI launch announcement](https://www.liquid.ai/blog/introducing-lfm2-5-the-next-generation-of-on-device-ai) |
| SmolLM3 | 2025-07-08 | [Hugging Face launch announcement](https://huggingface.co/blog/smollm3) |
| Qwen3 | 2025-04-29 | [Qwen launch announcement](https://qwenlm.github.io/blog/qwen3/) |
| Granite 3.3 | 2025-04-16 | [IBM release history](https://www.ibm.com/docs/en/watsonx/saas?topic=watsonx-whats-new) |
| Gemma 3 | 2025-03-12 | [Google launch announcement](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-3/) |
| DeepSeek R1 | 2025-01-20 | [DeepSeek release announcement](https://api-docs.deepseek.com/news/news250120/) |
| SmolLM2 | 2024-11-01 | [Contemporaneous launch reporting](https://venturebeat.com/ai/ai-on-your-smartphone-hugging-faces-smollm2-brings-powerful-models-to-the-palm-of-your-hand) |
| Llama 3.2 | 2024-09-25 | [Meta model card](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) |
| Qwen2.5 | 2024-09-19 | [Qwen launch announcement](https://qwenlm.github.io/blog/qwen2.5/) |
| Phi 3.5 | 2024-08 | [Microsoft model card](https://huggingface.co/microsoft/Phi-3.5-mini-instruct#training) |
| Llama 3.1 | 2024-07-23 | [Meta model card](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct) |
| Mistral Nemo | 2024-07-18 | [Mistral launch announcement](https://mistral.ai/news/mistral-nemo/) |

Precision and source differences:

- Phi 3.5's model card states only the release month. The CSV preserves `YYYY-MM`
  precision rather than inventing a day. Sorting uses the start of that month;
  the UI displays the original month-only value.
- Gemma dates use Google's public launch announcements. Google's release calendar
  lists earlier dates (March 31 for Gemma 4 and March 10 for Gemma 3); these are
  not substituted for the announcement dates above.
- Qwen3.5 uses the official repository's explicit February 16 release entry,
  although the linked launch blog is dated February 15. The Qwen3.5 repository
  now redirects to Qwen3.8 and retains its earlier release history.
- SmolLM2 uses contemporaneous launch reporting; the publisher's later paper
  publication date and repository creation dates are not treated as launch dates.

On mobile, families sort newest first, with undated custom families last and
alphabetical ordering for ties. Models remain smallest first within each family.
Desktop families retain alphabetical ordering. Saved revision-3 catalogues gain
only missing release metadata for matching built-in sources; custom sources,
custom dates, and model deletions are preserved.

All catalogue variants remain visible and downloadable regardless of device fit.
Compatibility advice informs the user; only fitting candidates receive recommendations.

`lib/ai/model_manager/model_catalogue_maid.dart` supplements the CSV with 76
publisher-verified variants requested from the MAID download references. These
include Phi 3 Mini, TinyLlama, Gemma 2, Gemmasutra Mini/Small, Qwen2.5 1.5B,
Tessa T1 3B and additional Qwen3.5 quantizations. Each row records the repository,
filename, immutable revision, exact byte size and LFS SHA-256 obtained from
`https://huggingface.co/api/models/{repository}?blobs=true` on 2026-11-18.
Projector files are excluded; this catalogue supplies text chat models.
Unverified family launch dates are omitted. Resource recommendations are
estimates, not proof of a successful device load.

Catalogue revision 5 adds these new entries to older saved catalogues while
preserving edited existing entries. New saves keep deliberate deletions.
Downloads show a dropdown per model with quantization, size and the recommendation
icon; estimated CSV sizes carry an approximation marker.
