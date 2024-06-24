#!/bin/zsh

show_summaries=false
staged_files=()
unstaged_files=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--summaries)
            show_summaries=true
            shift
            ;;
        *)
            echo "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

modified_files=($(git diff --name-only))

if [ ${#modified_files[@]} -eq 0 ]; then
    echo "${YELLOW}No modified files found.${NC}"
    exit 0
fi

# Configure less to pass color codes through
export LESS="-R"

# Trap to handle script exit
trap 'print_summary; exit' INT TERM EXIT

print_summary() {
    echo "\n${BLUE}Summary:${NC}"
    echo "${GREEN}Staged files (${#staged_files[@]}):${NC}"
    printf '%s\n' "${staged_files[@]}"

    echo "${RED}Unstaged files (${#unstaged_files[@]}):${NC}"
    printf '%s\n' "${unstaged_files[@]}"
}

for file in "${modified_files[@]}"; do
    if $show_summaries; then
        echo "${BLUE}Summary of changes in $file:${NC}"
        git diff --color=always --stat -- "$file"
    else
        git diff --color=always -- "$file" | less -R
    fi

    while true; do
        print -n "${YELLOW}[A]dd file to git, or go to [N]ext file${NC}"
        read -k1 next_choice
        echo ""  # Move to a new line
        case "${(L)next_choice}" in
            a)
                git add "$file"
                staged_files+=("$file")
                break
                ;;
            n)
                unstaged_files+=("$file")
                break
                ;;
            q)
                exit 0
                ;;
            *)
                echo "${RED}Invalid choice. Please enter 'a' or 'n'.${NC}"
                ;;
        esac
    done
done

# Prompt for commit or quit after viewing all files
prompt_commit_or_quit() {
    while true; do
        print -n "${YELLOW}Enter 'c' to commit or 'q' to quit: ${NC}"
        read -k1 choice
        echo ""  # Move to a new line
        case "${(L)choice}" in
            c)
                git commit
                exit 0
                ;;
            q)
                exit 0
                ;;
            *)
                echo "${RED}Invalid input. Please enter 'c' or 'q'.${NC}"
                ;;
        esac
    done
}

prompt_commit_or_quit