#!/bin/zsh

show_summaries=false
run_build=true
base=""
staged_files=()
unstaged_files=()
do_merge=false
merge_base=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -u|--summaries)
            show_summaries=true
            shift
            ;;
        -s|--skip-build)
            run_build=false
            shift
            ;;
        -b|--base)
            if [[ -n "$2" && "$2" != -* ]]; then
                base="$2"
                shift 2
            else
                echo "${RED}Error: Argument for $1 is missing${NC}" >&2
                exit 1
            fi
            ;;
        -m|--merge)
            if [[ -n "$2" && "$2" != -* ]]; then
                do_merge=true
                merge_base="$2"
                shift 2
            else
                echo "${YELLOW}Merge flag ignored. No base branch specified.${NC}"
                shift
            fi
            ;;
        *)
            echo "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# Run yarn build if not skipped
if $run_build; then
    echo "${BLUE}Running yarn build...${NC}"
    if ! yarn run build; then
        echo "${RED}yarn build failed. Exiting.${NC}"
        exit 1
    fi
    echo "${GREEN}yarn build completed successfully.${NC}"
fi

if [ -n "$base" ]; then
    modified_files=($(git diff --name-only "$base"))
else
    modified_files=($(git diff --name-only))
fi

if [ ${#modified_files[@]} -eq 0 ]; then
    echo "${YELLOW}No modified files found.${NC}"
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

get_line_stats() {
    local file="$1"
    local diff_command="git diff --numstat"
    if [ -n "$base" ]; then
        diff_command="$diff_command $base"
    fi
    local stats=$(eval "$diff_command -- \"$file\"")
    local additions=$(echo "$stats" | awk '{print $1}')
    local deletions=$(echo "$stats" | awk '{print $2}')
    echo "${GREEN}+$additions${NC}/${RED}-$deletions${NC}"
}

for file in "${modified_files[@]}"; do
    line_stats=$(get_line_stats "$file")
    echo "${BLUE}File: $file ${NC}(Changes: $line_stats)"

    if $show_summaries; then
        echo "${BLUE}Summary of changes in $file:${NC}"
        if [ -n "$base" ]; then
            git diff --color=always --stat "$base" -- "$file"
        else
            git diff --color=always --stat -- "$file"
        fi
    else
        (
            echo "${BLUE}File: $file ${NC}(Changes: $line_stats)"
            echo ""
            if [ -n "$base" ]; then
                git diff --color=always "$base" -- "$file"
            else
                git diff --color=always -- "$file"
            fi
        ) | less -R
    fi

    while true; do
        print -n "${YELLOW}[A]dd file to git, [R]estore file, go to [N]ext file, or [Q]uit: ${NC}"
        read -k1 next_choice
        echo ""  # Move to a new line
        case "${next_choice}" in
            a)
                git add "$file"
                staged_files+=("$file")
                break
                ;;
            R)
                echo "${YELLOW}Restoring $file...${NC}"
		if [ -n "$base" ]; then
			echo "git checkout $base $file"
			git checkout "$base" "$file"
		else
			git restore "$file"
		fi
                echo "${GREEN}File $file has been restored.${NC}"
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
                echo "${RED}Invalid choice. Please enter 'a', 'r', 'n', or 'q'.${NC}"
                ;;
        esac
    done
done

perform_merge() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local base=$merge_base

    echo "${BLUE}Performing merge process...${NC}"
    echo "${YELLOW}Current branch: $current_branch${NC}"
    echo "${YELLOW}Base branch: $base${NC}"

    # Checkout base branch
    if ! git checkout "$base"; then
        echo "${RED}Failed to checkout $base. Aborting merge process.${NC}"
        return 1
    fi

    # Squash merge the working branch
    if ! git merge --squash "$current_branch"; then
        echo "${RED}Failed to squash merge $current_branch into $base. Aborting merge process.${NC}"
        git checkout "$current_branch"
        return 1
    fi

    # Commit the merge
    if ! git commit -m "Squash merge $current_branch into $base"; then
        echo "${RED}Failed to commit the squash merge. Aborting merge process.${NC}"
        git checkout "$current_branch"
        return 1
    fi

    # Push the base branch
    if ! git push; then
        echo "${RED}Failed to push $base. Aborting merge process.${NC}"
        git checkout "$current_branch"
        return 1
    fi

    # Checkout the working branch
    if ! git checkout "$current_branch"; then
        echo "${RED}Failed to checkout $current_branch. Base branch has been updated and pushed.${NC}"
        return 1
    fi

    # Push the working branch
    if ! git push; then
        echo "${RED}Failed to push $current_branch. Base branch has been updated and pushed.${NC}"
        return 1
    fi

    echo "${GREEN}Merge process completed successfully.${NC}"
    return 0
}

prompt_commit_or_quit() {
    while true; do
	git status
        if $do_merge; then
            print -n "${YELLOW}[C]ommit, [A]mmend, or [Q]uit: ${NC}"
        else
            print -n "${YELLOW}[C]ommit, [A]mmend, [M]erge, or [Q]uit: ${NC}"
        fi
        read -k1 choice
        echo ""  # Move to a new line
        case "${(L)choice}" in
            a)
                git commit --amend
                exit 0
                ;;
            c)
                git commit
                exit 0
                ;;
            m)
                if ! $do_merge; then
                    print -n "${YELLOW}Enter base branch for merge: ${NC}"
                    read merge_base
                    if [ -n "$merge_base" ]; then
                        do_merge=true
                        perform_merge
                    else
                        echo "${RED}No base branch specified. Merge aborted.${NC}"
                    fi
                    exit 0
                else
                    echo "${RED}Merge option was already set via command line.${NC}"
                fi
                ;;
            q)
                exit 0
                ;;
            *)
                if $do_merge; then
                    echo "${RED}Invalid input. Please enter 'c', 'a', or 'q'.${NC}"
                else
                    echo "${RED}Invalid input. Please enter 'c', 'a', 'm', or 'q'.${NC}"
                fi
                ;;
        esac
    done
}

prompt_commit_or_quit

if $do_merge; then
    perform_merge
