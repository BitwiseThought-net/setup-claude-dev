#!/bin/bash

#export ANTHROPIC_BASE_URL="http://server.lan"
#export ANTHROPIC_API_KEY="ollama"
#claude
#claude --model qwen2.5-coder:14b
#claude --model qwen3.6:latest

#!/bin/bash
# Load aliases specifically for this runner
if [ -f "$HOME/.claude_aliases" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.claude_aliases"
fi

# Now you can use claude-local safely inside this script
claude-local









