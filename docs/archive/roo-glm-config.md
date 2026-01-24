# Roo Code GLM-4.7 Configuration

Since Ollama doesn't support the GLM-4.7 model directly (architecture compatibility issues), the model is running as an OpenAI-compatible API server.

## Configure Roo Code to Use GLM-4.7

1. Open VS Code Settings (Ctrl/Cmd + ,)
2. Search for "Roo Code" or "roo"
3. Look for Provider settings (similar to Ollama configuration)
4. Add a new provider or modify existing OpenAI provider:
   - **Provider Type**: OpenAI
   - **Base URL**: `http://localhost:8080`
   - **API Key**: Leave empty or use a dummy key (not required for local)
   - **Model Name**: `GLM-4.7-Flash-Q8` or any name
   - **Max Tokens**: 202752

## API Details

- **Endpoint**: `http://localhost:8080/v1/chat/completions`
- **Supported formats**: OpenAI Chat Completions API
- **Context window**: 202,752 tokens
- **Streaming**: Supported

## Usage

Once configured, you can select the GLM-4.7 provider in Roo Code for tasks that benefit from its advanced reasoning capabilities and long context.

## Container Management

Ensure the GLM server is running:
```bash
podman start glm-server
```

The server uses ~53GB VRAM and provides fast inference with AMD GPU acceleration.