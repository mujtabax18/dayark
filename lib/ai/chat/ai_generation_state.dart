/// Request lifecycle shared by mobile and desktop controls.
enum AiGenerationState {
  idle,
  preparing,
  loadingModel,
  processingPrompt,
  thinking,
  generating,
  cancelling,
  interrupted,
  completed,
  failed,
}
