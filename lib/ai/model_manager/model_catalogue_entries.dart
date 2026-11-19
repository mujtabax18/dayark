part of 'model_catalogue.dart';

// Publisher HF API metadata verified 2026-11-17. Pinned revisions and LFS hashes.
// Single-file text GGUF only; vision projectors and draft models are excluded.
List<AiCatalogueModel> _pinnedModels() => [
  AiCatalogueModel(
    id: 'gemma4-e4b',
    name: 'Gemma 4 E4B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF'),
    estimatedRamBytes: 8 * aiGiB,
    estimatedDiskBytes: 4590807392,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/8903cb408c7df39cde2ed15fac397e6d7be92951/gemma-4-E4B-it-Q4_0.gguf',
      ),
      sha256:
          'a555b900214b477d8880e7832e0b8925e139b0159640036b09fe472b6f2097f2',
      bytes: 4590807392,
      revision: '8903cb408c7df39cde2ed15fac397e6d7be92951',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-12b',
    name: 'Gemma 4 12B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF'),
    estimatedRamBytes: 12 * aiGiB,
    estimatedDiskBytes: 7219673216,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF/resolve/501d13dba70e3c02b1b12c78fd9e6b08ad413960/gemma-4-12B-it-Q4_0.gguf',
      ),
      sha256:
          '3712b9bd32cae83a22f67ee7a4466d8d7a4f21646ac8a07d19bf9418e8767a70',
      bytes: 7219673216,
      revision: '501d13dba70e3c02b1b12c78fd9e6b08ad413960',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-26b',
    name: 'Gemma 4 26B A4B',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF',
    ),
    estimatedRamBytes: 24 * aiGiB,
    estimatedDiskBytes: 14618145824,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF/resolve/1ca99aae748b4b01f609fa51eb23682ee5f00b85/gemma-4-26B-A4B-it-Q4_0.gguf',
      ),
      sha256:
          'd208665ab1cd3a69f7a9a4bc59430e8448c8093d9b06334f566ac59d6d504a03',
      bytes: 14618145824,
      revision: '1ca99aae748b4b01f609fa51eb23682ee5f00b85',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-31b',
    name: 'Gemma 4 31B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF'),
    estimatedRamBytes: 28 * aiGiB,
    estimatedDiskBytes: 17992313088,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/f39d380138390ea246513ff0f087352f3cfc3a1b/gemma-4-31B-it-Q4_0.gguf',
      ),
      sha256:
          '031dc1c5fa9c5a0abbf3c39c5173fb2af65f5ac2dc2a090268561d3c72dcd834',
      bytes: 17992313088,
      revision: 'f39d380138390ea246513ff0f087352f3cfc3a1b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-e2b',
    name: 'Gemma 4 E2B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF'),
    estimatedRamBytes: 5 * aiGiB,
    estimatedDiskBytes: 2841481184,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF/resolve/2a8538c2e2d4687953a86c422c7c623cfd022880/gemma-4-E2B-it-Q4_0.gguf',
      ),
      sha256:
          '8e30dff3ac4c8434c49a7036fa15564bdbb6044e42bf04550bf1a096ad7e6a52',
      bytes: 2841481184,
      revision: '2a8538c2e2d4687953a86c422c7c623cfd022880',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-270m-it',
    name: 'gemma 3 270m',
    license: 'See publisher license',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-270m-it-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 291545600,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-270m-it-GGUF/resolve/e7647be17ae1108f2f605ed061ca0608b171afff/gemma-3-270m-it-Q8_0.gguf',
      ),
      sha256:
          '0ef57d2c838458a1952664260dcba38e5bdda37494f3af732f06e4add24068e3',
      bytes: 291545600,
      revision: 'e7647be17ae1108f2f605ed061ca0608b171afff',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-1b-it',
    name: 'gemma 3 1b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 806058240,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/f9c28bcd85737ffc5aef028638d3341d49869c27/gemma-3-1b-it-Q4_K_M.gguf',
      ),
      sha256:
          '8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135',
      bytes: 806058240,
      revision: 'f9c28bcd85737ffc5aef028638d3341d49869c27',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-4b-it',
    name: 'gemma 3 4b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF'),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 2489757856,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/d0976223747697cb51e056d85c532013931fe52e/gemma-3-4b-it-Q4_K_M.gguf',
      ),
      sha256:
          '882e8d2db44dc554fb0ea5077cb7e4bc49e7342a1f0da57901c0802ea21a0863',
      bytes: 2489757856,
      revision: 'd0976223747697cb51e056d85c532013931fe52e',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-0-6b',
    name: 'Qwen3 0.6B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-0.6B-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 639446688,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/23749fefcc72300e3a2ad315e1317431b06b590a/Qwen3-0.6B-Q8_0.gguf',
      ),
      sha256:
          '9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031',
      bytes: 639446688,
      revision: '23749fefcc72300e3a2ad315e1317431b06b590a',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-1-7b',
    name: 'Qwen3 1.7B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-1.7B-GGUF'),
    estimatedRamBytes: 4 * aiGiB,
    estimatedDiskBytes: 1834426016,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/90862c4b9d2787eaed51d12237eafdfe7c5f6077/Qwen3-1.7B-Q8_0.gguf',
      ),
      sha256:
          '061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a',
      bytes: 1834426016,
      revision: '90862c4b9d2787eaed51d12237eafdfe7c5f6077',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-4b',
    name: 'Qwen3 4B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-4B-GGUF'),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 2497280256,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/bc640142c66e1fdd12af0bd68f40445458f3869b/Qwen3-4B-Q4_K_M.gguf',
      ),
      sha256:
          '7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5',
      bytes: 2497280256,
      revision: 'bc640142c66e1fdd12af0bd68f40445458f3869b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-8b',
    name: 'Qwen3 8B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-8B-GGUF'),
    estimatedRamBytes: 10 * aiGiB,
    estimatedDiskBytes: 5027783488,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/7c41481f57cb95916b40956ab2f0b139b296d974/Qwen3-8B-Q4_K_M.gguf',
      ),
      sha256:
          'd98cdcbd03e17ce47681435b5150e34c1417f50b5c0019dd560e4882c5745785',
      bytes: 5027783488,
      revision: '7c41481f57cb95916b40956ab2f0b139b296d974',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-1b-instruct',
    name: 'Llama 3.2 1B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF',
    ),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 807694464,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/067b946cf014b7c697f3654f621d577a3e3afd1c/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      ),
      sha256:
          '6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83',
      bytes: 807694464,
      revision: '067b946cf014b7c697f3654f621d577a3e3afd1c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-3b-instruct',
    name: 'Llama 3.2 3B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF',
    ),
    estimatedRamBytes: 5 * aiGiB,
    estimatedDiskBytes: 2019377696,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/5ab33fa94d1d04e903623ae72c95d1696f09f9e8/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      ),
      sha256:
          '6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff',
      bytes: 2019377696,
      revision: '5ab33fa94d1d04e903623ae72c95d1696f09f9e8',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-1-8b-instruct',
    name: 'Llama 3.1 8B',
    license: 'llama3.1',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF',
    ),
    estimatedRamBytes: 10 * aiGiB,
    estimatedDiskBytes: 4920739232,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/bf5b95e96dac0462e2a09145ec66cae9a3f12067/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf',
      ),
      sha256:
          '7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c',
      bytes: 4920739232,
      revision: 'bf5b95e96dac0462e2a09145ec66cae9a3f12067',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'phi-3-5-mini-instruct',
    name: 'Phi 3.5 mini',
    license: 'mit',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF',
    ),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 2393232672,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/6d70da17e749a471ccb62ade694486011a75cda3/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      ),
      sha256:
          'e4165e3a71af97f1b4820da61079826d8752a2088e313af0c7d346796c38eff5',
      bytes: 2393232672,
      revision: '6d70da17e749a471ccb62ade694486011a75cda3',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'smollm2-360m-instruct',
    name: 'SmolLM2 360M',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
    ),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 386404992,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/593b5a2e04c8f3e4ee880263f93e0bd2901ad47f/smollm2-360m-instruct-q8_0.gguf',
      ),
      sha256:
          '48ab3034d0dd401fbc721eb1df3217902fee7dab9078992d66431f09b7750201',
      bytes: 386404992,
      revision: '593b5a2e04c8f3e4ee880263f93e0bd2901ad47f',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'smollm2-1-7b-instruct',
    name: 'SmolLM2 1.7B',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF',
    ),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 1055609536,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/2d4a76a30b4af41ecd395c35725ac11688d4cfe4/smollm2-1.7b-instruct-q4_k_m.gguf',
      ),
      sha256:
          'decd2598bc2c8ed08c19adc3c8fdd461ee19ed5708679d1c54ef54a5a30d4f33',
      bytes: 1055609536,
      revision: '2d4a76a30b4af41ecd395c35725ac11688d4cfe4',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-350m',
    name: 'LFM2 350M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-350M-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 229309376,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-350M-GGUF/resolve/8fdc9d526b7ed346b19257551b05816c7912ecc2/LFM2-350M-Q4_K_M.gguf',
      ),
      sha256:
          'a4d000c7064bd3b2e42c6845836286a899a4e79cf1791da1a6797b58d575957d',
      bytes: 229309376,
      revision: '8fdc9d526b7ed346b19257551b05816c7912ecc2',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-700m',
    name: 'LFM2 700M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-700M-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 468624320,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-700M-GGUF/resolve/fd39e80d7a5ac61494ffff577e61bbbfddbd0d02/LFM2-700M-Q4_K_M.gguf',
      ),
      sha256:
          '684e8406dc13321452b3f6aeca432776e2a6a7e1ad6c23f7887b8fe3efbe2efa',
      bytes: 468624320,
      revision: 'fd39e80d7a5ac61494ffff577e61bbbfddbd0d02',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-1-2b',
    name: 'LFM2 1.2B',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 730893248,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF/resolve/5399e76c648f4eb8c053feb1ab747277dea5bf8b/LFM2-1.2B-Q4_K_M.gguf',
      ),
      sha256:
          '55175400e3f509a9616227afeffd58d87e80b9f628a5d3d54ada884d85221fed',
      bytes: 730893248,
      revision: '5399e76c648f4eb8c053feb1ab747277dea5bf8b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-12b-it',
    name: 'gemma 3 12b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF'),
    estimatedRamBytes: 14 * aiGiB,
    estimatedDiskBytes: 7300574976,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF/resolve/ec0cbabd8dbff316f659876a50202295c3c4a314/gemma-3-12b-it-Q4_K_M.gguf',
      ),
      sha256:
          '7bb69bff3f48a7b642355d64a90e481182a7794707b3133890646b1efa778ff5',
      bytes: 7300574976,
      revision: 'ec0cbabd8dbff316f659876a50202295c3c4a314',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'smollm2-135m-instruct',
    name: 'SmolLM2 135M',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF',
    ),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 105454432,
    quantization: 'Q4_K_M',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/09816acd5d99df7be770d85ea30822623dab342c/SmolLM2-135M-Instruct-Q4_K_M.gguf',
      ),
      sha256:
          '2e8040ceae7815abe0dcb3540b9995eaa1fa0d2ca9e797d0a635ae4433c68c2d',
      bytes: 105454432,
      revision: '09816acd5d99df7be770d85ea30822623dab342c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-e4b-q8_0',
    name: 'Gemma 4 E4B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF'),
    estimatedRamBytes: 9 * aiGiB,
    estimatedDiskBytes: 8031237344,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/8903cb408c7df39cde2ed15fac397e6d7be92951/gemma-4-E4B-it-Q8_0.gguf',
      ),
      sha256:
          '49008e7cc7edadf154c8748904a89ee86eb6905d220aac568f6b7b92ca6aa0c6',
      bytes: 8031237344,
      revision: '8903cb408c7df39cde2ed15fac397e6d7be92951',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-12b-q8_0',
    name: 'Gemma 4 12B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF'),
    estimatedRamBytes: 14 * aiGiB,
    estimatedDiskBytes: 12669641920,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF/resolve/501d13dba70e3c02b1b12c78fd9e6b08ad413960/gemma-4-12B-it-Q8_0.gguf',
      ),
      sha256:
          '3730903965b3e57bcad0a387110322ce66409559c356a1ae1b61701024e5ce60',
      bytes: 12669641920,
      revision: '501d13dba70e3c02b1b12c78fd9e6b08ad413960',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-26b-q8_0',
    name: 'Gemma 4 26B A4B',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF',
    ),
    estimatedRamBytes: 27 * aiGiB,
    estimatedDiskBytes: 26859860992,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF/resolve/1ca99aae748b4b01f609fa51eb23682ee5f00b85/gemma-4-26B-A4B-it-Q8_0.gguf',
      ),
      sha256:
          'b5108fd13147d1c866bb595295bc9d56f5fe744d7209f18421031d0cc47009c6',
      bytes: 26859860992,
      revision: '1ca99aae748b4b01f609fa51eb23682ee5f00b85',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-31b-q8_0',
    name: 'Gemma 4 31B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF'),
    estimatedRamBytes: 32 * aiGiB,
    estimatedDiskBytes: 32635676896,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/f39d380138390ea246513ff0f087352f3cfc3a1b/gemma-4-31B-it-Q8_0.gguf',
      ),
      sha256:
          'fcd52cebacb165a98df5abe6fb70dbf076835f4a06e064ffb33dd739b8835c9c',
      bytes: 32635676896,
      revision: 'f39d380138390ea246513ff0f087352f3cfc3a1b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma4-e2b-q8_0',
    name: 'Gemma 4 E2B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF'),
    estimatedRamBytes: 7 * aiGiB,
    estimatedDiskBytes: 4967491520,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF/resolve/2a8538c2e2d4687953a86c422c7c623cfd022880/gemma-4-E2B-it-Q8_0.gguf',
      ),
      sha256:
          'c36d5e6be0d91124d8b995f5ad4e1ab0d307f6d95cdd08308820350dbd96ad15',
      bytes: 4967491520,
      revision: '2a8538c2e2d4687953a86c422c7c623cfd022880',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-1b-it-q8_0',
    name: 'gemma 3 1b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 1069306368,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/f9c28bcd85737ffc5aef028638d3341d49869c27/gemma-3-1b-it-Q8_0.gguf',
      ),
      sha256:
          'b205840c5dcef55078e37d344677869a714ffd42a4ae448c48dcfb52e4bb10d5',
      bytes: 1069306368,
      revision: 'f9c28bcd85737ffc5aef028638d3341d49869c27',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-4b-it-q8_0',
    name: 'gemma 3 4b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF'),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 4130226336,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/d0976223747697cb51e056d85c532013931fe52e/gemma-3-4b-it-Q8_0.gguf',
      ),
      sha256:
          '97b06383df48336e7d2f9b56b6ce545e0fa476407a62c0bd081b53447a58e644',
      bytes: 4130226336,
      revision: 'd0976223747697cb51e056d85c532013931fe52e',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-4b-q8_0',
    name: 'Qwen3 4B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-4B-GGUF'),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 4280404704,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/bc640142c66e1fdd12af0bd68f40445458f3869b/Qwen3-4B-Q8_0.gguf',
      ),
      sha256:
          '8c2f07f26af9747e41988551106f149b03eb9b5cb6df636027b6bf6278473300',
      bytes: 4280404704,
      revision: 'bc640142c66e1fdd12af0bd68f40445458f3869b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'qwen3-8b-q8_0',
    name: 'Qwen3 8B',
    license: 'apache-2.0',
    source: Uri.parse('https://huggingface.co/Qwen/Qwen3-8B-GGUF'),
    estimatedRamBytes: 10 * aiGiB,
    estimatedDiskBytes: 8709518112,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/7c41481f57cb95916b40956ab2f0b139b296d974/Qwen3-8B-Q8_0.gguf',
      ),
      sha256:
          '408b955510e196121c1c375201744783b5c9a43c7956d73fc78df54c66e883d6',
      bytes: 8709518112,
      revision: '7c41481f57cb95916b40956ab2f0b139b296d974',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-1b-instruct-q4_0',
    name: 'Llama 3.2 1B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF',
    ),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 773025920,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/067b946cf014b7c697f3654f621d577a3e3afd1c/Llama-3.2-1B-Instruct-Q4_0.gguf',
      ),
      sha256:
          'fa0390e7c043f89ae1847bd6682d748041a99d4ef3de0e0b27d33b6af97a8be8',
      bytes: 773025920,
      revision: '067b946cf014b7c697f3654f621d577a3e3afd1c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-1b-instruct-q8_0',
    name: 'Llama 3.2 1B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF',
    ),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 1321083008,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/067b946cf014b7c697f3654f621d577a3e3afd1c/Llama-3.2-1B-Instruct-Q8_0.gguf',
      ),
      sha256:
          '432f310a77f4650a88d0fd59ecdd7cebed8d684bafea53cbff0473542964f0c3',
      bytes: 1321083008,
      revision: '067b946cf014b7c697f3654f621d577a3e3afd1c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-3b-instruct-q4_0',
    name: 'Llama 3.2 3B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF',
    ),
    estimatedRamBytes: 5 * aiGiB,
    estimatedDiskBytes: 1921909280,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/5ab33fa94d1d04e903623ae72c95d1696f09f9e8/Llama-3.2-3B-Instruct-Q4_0.gguf',
      ),
      sha256:
          '4d491003bf6b470e4d04233824c5c939b76d6c81974ba17a3ff207343e1d8e85',
      bytes: 1921909280,
      revision: '5ab33fa94d1d04e903623ae72c95d1696f09f9e8',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-2-3b-instruct-q8_0',
    name: 'Llama 3.2 3B',
    license: 'llama3.2',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF',
    ),
    estimatedRamBytes: 5 * aiGiB,
    estimatedDiskBytes: 3421899296,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/5ab33fa94d1d04e903623ae72c95d1696f09f9e8/Llama-3.2-3B-Instruct-Q8_0.gguf',
      ),
      sha256:
          'b5607b5090a8280063fff2d706bb3408ca6542341b06aab39c3eca0a28575921',
      bytes: 3421899296,
      revision: '5ab33fa94d1d04e903623ae72c95d1696f09f9e8',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'llama-3-1-8b-instruct-q8_0',
    name: 'Llama 3.1 8B',
    license: 'llama3.1',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF',
    ),
    estimatedRamBytes: 10 * aiGiB,
    estimatedDiskBytes: 8540775840,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/bf5b95e96dac0462e2a09145ec66cae9a3f12067/Meta-Llama-3.1-8B-Instruct-Q8_0.gguf',
      ),
      sha256:
          '9da71c45c90a821809821244d4971e5e5dfad7eb091f0b8ff0546392393b6283',
      bytes: 8540775840,
      revision: 'bf5b95e96dac0462e2a09145ec66cae9a3f12067',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'phi-3-5-mini-instruct-q4_0',
    name: 'Phi 3.5 mini',
    license: 'mit',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF',
    ),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 2182468896,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/6d70da17e749a471ccb62ade694486011a75cda3/Phi-3.5-mini-instruct-Q4_0.gguf',
      ),
      sha256:
          '6e0a4c93fe5db9408348cd2cbd15eee6f448efe6f91255a208c2d28701259b1d',
      bytes: 2182468896,
      revision: '6d70da17e749a471ccb62ade694486011a75cda3',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'phi-3-5-mini-instruct-q8_0',
    name: 'Phi 3.5 mini',
    license: 'mit',
    source: Uri.parse(
      'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF',
    ),
    estimatedRamBytes: 6 * aiGiB,
    estimatedDiskBytes: 4061222688,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/6d70da17e749a471ccb62ade694486011a75cda3/Phi-3.5-mini-instruct-Q8_0.gguf',
      ),
      sha256:
          '76fbf02f6fe92af57dbd818409bc8a0240026f1f3609bb405c3be94c973fb823',
      bytes: 4061222688,
      revision: '6d70da17e749a471ccb62ade694486011a75cda3',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-350m-q4_0',
    name: 'LFM2 350M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-350M-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 219306944,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-350M-GGUF/resolve/8fdc9d526b7ed346b19257551b05816c7912ecc2/LFM2-350M-Q4_0.gguf',
      ),
      sha256:
          '8e3ebc1c608dc8683adf8c3b3e6a40e2f4eab22aa33b908bff2ac03a1c16d796',
      bytes: 219306944,
      revision: '8fdc9d526b7ed346b19257551b05816c7912ecc2',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-350m-q8_0',
    name: 'LFM2 350M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-350M-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 379214784,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-350M-GGUF/resolve/8fdc9d526b7ed346b19257551b05816c7912ecc2/LFM2-350M-Q8_0.gguf',
      ),
      sha256:
          'b7bfeab6495a1ae3ae78811c1297df9f301b35261ff9580d42fb30dc4dc9034b',
      bytes: 379214784,
      revision: '8fdc9d526b7ed346b19257551b05816c7912ecc2',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-700m-q4_0',
    name: 'LFM2 700M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-700M-GGUF'),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 446321600,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-700M-GGUF/resolve/fd39e80d7a5ac61494ffff577e61bbbfddbd0d02/LFM2-700M-Q4_0.gguf',
      ),
      sha256:
          'bf9c70678aff2a6ee2152b6fef4b2993892eae6449d056cf77cc1e34072424b3',
      bytes: 446321600,
      revision: 'fd39e80d7a5ac61494ffff577e61bbbfddbd0d02',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-700m-q8_0',
    name: 'LFM2 700M',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-700M-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 791565248,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-700M-GGUF/resolve/fd39e80d7a5ac61494ffff577e61bbbfddbd0d02/LFM2-700M-Q8_0.gguf',
      ),
      sha256:
          '0967d902ed270d07cb374a1972bb5da4338d2a303b565cf4eb7948b958e751ab',
      bytes: 791565248,
      revision: 'fd39e80d7a5ac61494ffff577e61bbbfddbd0d02',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-1-2b-q4_0',
    name: 'LFM2 1.2B',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 695749568,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF/resolve/5399e76c648f4eb8c053feb1ab747277dea5bf8b/LFM2-1.2B-Q4_0.gguf',
      ),
      sha256:
          '2cd9650c6ca71dca428cccb552b65ebc027f6c86c48e530a9d414fd67b33530b',
      bytes: 695749568,
      revision: '5399e76c648f4eb8c053feb1ab747277dea5bf8b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'lfm2-1-2b-q8_0',
    name: 'LFM2 1.2B',
    license: 'other',
    source: Uri.parse('https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF'),
    estimatedRamBytes: 3 * aiGiB,
    estimatedDiskBytes: 1246251968,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF/resolve/5399e76c648f4eb8c053feb1ab747277dea5bf8b/LFM2-1.2B-Q8_0.gguf',
      ),
      sha256:
          '0d9ec100a0f33048168d1d5b9fb6403f4836adcbbe9c3f2ab7794c96ffee3c3b',
      bytes: 1246251968,
      revision: '5399e76c648f4eb8c053feb1ab747277dea5bf8b',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'gemma-3-12b-it-q8_0',
    name: 'gemma 3 12b',
    license: 'gemma',
    source: Uri.parse('https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF'),
    estimatedRamBytes: 14 * aiGiB,
    estimatedDiskBytes: 12509949696,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF/resolve/ec0cbabd8dbff316f659876a50202295c3c4a314/gemma-3-12b-it-Q8_0.gguf',
      ),
      sha256:
          '0fb3edf649e9e268700467c02d11513a7e401e7c2ff95d4e1420dfe96da73990',
      bytes: 12509949696,
      revision: 'ec0cbabd8dbff316f659876a50202295c3c4a314',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'smollm2-135m-instruct-q4_0',
    name: 'SmolLM2 135M',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF',
    ),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 91893088,
    quantization: 'Q4_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/09816acd5d99df7be770d85ea30822623dab342c/SmolLM2-135M-Instruct-Q4_0.gguf',
      ),
      sha256:
          'bcc3af2849ad6095af57e9b5cd43775256efdc66e306acb529172f92d0c04b03',
      bytes: 91893088,
      revision: '09816acd5d99df7be770d85ea30822623dab342c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
  AiCatalogueModel(
    id: 'smollm2-135m-instruct-q8_0',
    name: 'SmolLM2 135M',
    license: 'apache-2.0',
    source: Uri.parse(
      'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF',
    ),
    estimatedRamBytes: 2 * aiGiB,
    estimatedDiskBytes: 144811360,
    quantization: 'Q8_0',
    artifact: AiModelArtifact(
      url: Uri.parse(
        'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/09816acd5d99df7be770d85ea30822623dab342c/SmolLM2-135M-Instruct-Q8_0.gguf',
      ),
      sha256:
          '5a1395716f7913741cc51d98581b9b1228d80987a9f7d3664106742eb06bba83',
      bytes: 144811360,
      revision: '09816acd5d99df7be770d85ea30822623dab342c',
      redirectHosts: [
        'huggingface.co',
        'cas-bridge.xethub.hf.co',
        'us.aws.cdn.hf.co',
      ],
    ),
  ),
];
