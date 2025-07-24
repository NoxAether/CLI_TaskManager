#!/usr/bin/env sh

# Define all colors needed for both prompt and functions
export CORPO_BLUE_RAW='\e[38;5;27m'
export NEON_RED_RAW='\e[38;5;197m'
export NEON_PINK_RAW='\e[38;5;201m'
export TECH_YELLOW_RAW='\e[38;5;220m'
export NETWATCH_GREEN_RAW='\e[38;5;46m'
export ARASAKA_RED_RAW='\e[38;5;160m'
export RIPPER_TEAL_RAW='\e[38;5;87m'
export RESET_RAW='\e[0m'

# Add PS1-formatted versions
export CORPO_BLUE='\[\e[38;5;27m\]'
export NEON_RED='\[\e[38;5;197m\]'
export NEON_PINK='\[\e[38;5;201m\]'
export TECH_YELLOW='\[\e[38;5;220m\]'
export NETWATCH_GREEN='\[\e[38;5;46m\]'
export ARASAKA_RED='\[\e[38;5;160m\]'
export RIPPER_TEAL='\[\e[38;5;87m\]'
export RESET='\[\e[0m\]'

# Build the Prompt
function build_prompt {
    local task_display=$(task_prompt)
    PS1="\n${CORPO_BLUE}╭─${task_display}"
    PS1+="\n${CORPO_BLUE}╰─[${NEON_PINK}\u${CORPO_BLUE}@${NEON_RED}\h${CORPO_BLUE}:${NETWATCH_GREEN}\w${CORPO_BLUE}]"
    PS1+="\n${NEON_RED}λ ${RESET}"
}

PROMPT_COMMAND='build_prompt'
