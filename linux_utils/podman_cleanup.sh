#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/podman_cleanup.sh
# Safe Podman cleanup helper focused on keeping local storage metadata lean.
#
# Behavior:
# - Always previews what will be removed
# - Default run asks for confirmation before deleting anything
# - DRY_RUN=1 shows the preview and exits without deleting anything
# - --select opens a terminal TUI (fzf) to choose any containers/images
# - Default mode removes only:
#   - non-running containers
#   - untagged ('<none>' / '<none>') images
# - Select mode can remove any containers and any images you explicitly mark
#
# Usage:
#   ./podman_cleanup.sh
#   ./podman_cleanup.sh --select
#   DRY_RUN=1 ./podman_cleanup.sh
#   AUTO_APPROVE=1 ./podman_cleanup.sh
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

err() {
    print_header "ERROR\n$*" "$RED" >&2
}

SELECT_MODE=0
SELECTED_CONTAINERS=()
SELECTED_IMAGES=()
CURRENT_ACTION="initializing"

print_header() {
    local full_text="$1"
    local color="$2"
    local max_len=0

    while IFS= read -r line; do
        local clean_line
        clean_line=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local line_len=${#clean_line}
        if (( line_len > max_len )); then
            max_len=$line_len
        fi
    done <<< "$(echo -e "$full_text")"

    local box_width=$((max_len + 4))
    local horizontal_line
    horizontal_line=$(printf '═%.0s' $(seq 1 "$box_width"))
    echo -e "${color}╔${horizontal_line}╗${NC}"

    while IFS= read -r line; do
        printf "${color}║  ${NC}%-${max_len}s${color}  ║${NC}\n" "$line"
    done <<< "$(echo -e "$full_text")"

    echo -e "${color}╚${horizontal_line}╝${NC}"
}

usage() {
    cat <<'USAGE'
Usage:
  ./podman_cleanup.sh [--select] [--help]

Options:
  --select   Open an fzf terminal selector to choose any containers/images
  --help     Show this help text

Environment:
  DRY_RUN=1       Show preview only; do not delete anything
  AUTO_APPROVE=1  Skip the final confirmation prompt
USAGE
}

handle_error() {
    local exit_code=$?
    echo
    print_header "Podman cleanup failed while ${CURRENT_ACTION}" "$RED"
    exit "$exit_code"
}

trap handle_error ERR

is_true() {
    case "${1,,}" in
        1|true|yes|y|on) return 0 ;;
        *) return 1 ;;
    esac
}

is_interactive() {
    [[ -t 0 && -t 1 ]]
}

count_lines() {
    awk 'NF { count++ } END { print count + 0 }'
}

truncate_text() {
    local max_len="$1"
    local text="$2"

    if (( ${#text} > max_len )); then
        printf '%s…' "${text:0:max_len-1}"
    else
        printf '%s' "$text"
    fi
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --select)
                SELECT_MODE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                err "Unknown argument: $1"
                usage >&2
                exit 2
                ;;
        esac
        shift
    done
}

list_all_containers() {
    podman ps -a --format '{{printf "%s\t%s\t%s\t%s" .ID .Names .State .Image}}' || true
}

list_non_running_containers() {
    list_all_containers | awk -F $'\t' 'BEGIN { IGNORECASE=1 } NF && tolower($3) != "running" { print }'
}

list_all_images() {
    podman images -a --format '{{printf "%s\t%s\t%s\t%s" .ID .Repository .Tag .CreatedSince}}' | awk -F $'\t' 'NF && !seen[$1]++ { print }' || true
}

list_none_images() {
    list_all_images | awk -F $'\t' 'NF && (($2 == "<none>" || $2 == "") && ($3 == "<none>" || $3 == "")) { print }' || true
}

count_non_running_containers() {
    list_non_running_containers | count_lines
}

count_none_images() {
    list_none_images | count_lines
}

show_containers_from_data() {
    local data="$1"
    local container_id container_name container_state container_image

    if [[ -z "$data" ]]; then
        echo "  - none"
        return
    fi

    while IFS=$'\t' read -r container_id container_name container_state container_image; do
        [[ -n "$container_id" ]] || continue
        printf '  - %s\t%s\t%s\t%s\n' "$container_id" "$container_name" "$container_state" "$container_image"
    done <<< "$data"
}

show_images_from_data() {
    local data="$1"
    local image_id repository tag created_since

    if [[ -z "$data" ]]; then
        echo "  - none"
        return
    fi

    while IFS=$'\t' read -r image_id repository tag created_since; do
        [[ -n "$image_id" ]] || continue
        printf '  - %s\t%s:%s\t%s\n' "$image_id" "$repository" "$tag" "$created_since"
    done <<< "$data"
}

show_non_running_containers() {
    show_containers_from_data "$(list_non_running_containers)"
}

show_none_images() {
    show_images_from_data "$(list_none_images)"
}

filter_containers_by_selection() {
    local containers_output container_id container_name container_state container_image
    local -A selected=()

    for container_id in "${SELECTED_CONTAINERS[@]}"; do
        selected["$container_id"]=1
    done

    containers_output="$(list_all_containers)"
    while IFS=$'\t' read -r container_id container_name container_state container_image; do
        [[ -n "$container_id" ]] || continue
        if [[ -n "${selected[$container_id]:-}" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$container_id" "$container_name" "$container_state" "$container_image"
        fi
    done <<< "$containers_output"
}

filter_images_by_selection() {
    local images_output image_id repository tag created_since
    local -A selected=()

    for image_id in "${SELECTED_IMAGES[@]}"; do
        selected["$image_id"]=1
    done

    images_output="$(list_all_images)"
    while IFS=$'\t' read -r image_id repository tag created_since; do
        [[ -n "$image_id" ]] || continue
        if [[ -n "${selected[$image_id]:-}" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$image_id" "$repository" "$tag" "$created_since"
        fi
    done <<< "$images_output"
}

show_selected_containers() {
    show_containers_from_data "$(filter_containers_by_selection)"
}

show_selected_images() {
    show_images_from_data "$(filter_images_by_selection)"
}

count_remaining_selected_containers() {
    filter_containers_by_selection | count_lines
}

count_remaining_selected_images() {
    filter_images_by_selection | count_lines
}

build_fzf_container_lines() {
    local data="$1"
    local container_id container_name container_state container_image

    while IFS=$'\t' read -r container_id container_name container_state container_image; do
        [[ -n "$container_id" ]] || continue
        printf '%s\t%s\t%s\t%s\n' \
            "$container_id" \
            "$(truncate_text 26 "$container_name")" \
            "$container_state" \
            "$(truncate_text 60 "$container_image")"
    done <<< "$data"
}

build_fzf_image_lines() {
    local data="$1"
    local image_id repository tag created_since

    while IFS=$'\t' read -r image_id repository tag created_since; do
        [[ -n "$image_id" ]] || continue
        printf '%s\t%s\t%s\t%s\n' \
            "$image_id" \
            "$(truncate_text 28 "$repository")" \
            "$(truncate_text 20 "$tag")" \
            "$created_since"
    done <<< "$data"
}

extract_ids_from_selection() {
    awk -F $'\t' 'NF { print $1 }'
}

fzf_select_ids() {
    local title="$1"
    local header="$2"
    local data="$3"
    local kind="$4"
    local formatted_data selection

    [[ -n "$data" ]] || return 0

    if [[ "$kind" == "container" ]]; then
        formatted_data="$(build_fzf_container_lines "$data")"
    else
        formatted_data="$(build_fzf_image_lines "$data")"
    fi

    [[ -n "$formatted_data" ]] || return 0

    selection="$(printf '%s\n' "$formatted_data" | \
        fzf --multi \
            --ansi \
            --layout=reverse \
            --height=100% \
            --border \
            --cycle \
            --prompt "$title> " \
            --header "$header" \
            --bind 'tab:toggle+down,shift-tab:toggle+up,ctrl-a:select-all,ctrl-d:deselect-all' \
            --preview 'printf "%s\n" {}' \
            --preview-window 'down,3,wrap' \
            --delimiter=$'\t' \
            --with-nth=1,2,3,4)" || return 1

    printf '%s\n' "$selection" | extract_ids_from_selection
}

select_targets_tui() {
    local containers_output images_output

    if ! have fzf; then
        err "'--select' requires 'fzf'. Run linux_utils/toolchains/bootstrap_toolchains.sh or install it with apt."
        exit 1
    fi

    if ! is_interactive; then
        err "'--select' requires an interactive terminal."
        exit 1
    fi

    containers_output="$(list_all_containers)"
    images_output="$(list_all_images)"

    if [[ -z "$containers_output" && -z "$images_output" ]]; then
        print_header "Nothing eligible" "$BLUE"
        echo "No containers or images are currently available for terminal selection."
        exit 0
    fi

    if [[ -n "$containers_output" ]]; then
        if ! mapfile -t SELECTED_CONTAINERS < <(fzf_select_ids \
            "containers" \
            "Tab marks rows, Enter confirms, Esc cancels. Running containers can be selected here." \
            "$containers_output" \
            "container"); then
            print_header "Selection cancelled" "$YELLOW"
            echo "Nothing was deleted."
            exit 0
        fi
    fi

    if [[ -n "$images_output" ]]; then
        if ! mapfile -t SELECTED_IMAGES < <(fzf_select_ids \
            "images" \
            "Tab marks rows, Enter confirms, Esc cancels. Tagged and <none>:<none> images can be selected here." \
            "$images_output" \
            "image"); then
            print_header "Selection cancelled" "$YELLOW"
            echo "Nothing was deleted."
            exit 0
        fi
    fi
}

preview_cleanup() {
    local container_count image_count

    if (( SELECT_MODE )); then
        container_count=${#SELECTED_CONTAINERS[@]}
        image_count=${#SELECTED_IMAGES[@]}

        print_header "Preview: Selected Podman cleanup" "$YELLOW"
        echo "fzf mode: the marked items below would be removed. This mode may include running containers and tagged images."
        echo
        echo "Selected containers:             $container_count"
        echo "Selected images:                 $image_count"
        echo
        echo "Containers:"
        show_selected_containers
        echo
        echo "Images:"
        show_selected_images
        echo
        return
    fi

    container_count="$(count_non_running_containers)"
    image_count="$(count_none_images)"

    print_header "Preview: Safe Podman cleanup" "$YELLOW"
    echo "Terraform-like preview: the following items would be removed."
    echo
    echo "Non-running containers targeted: $container_count"
    echo "<none>:<none> images targeted:   $image_count"
    echo
    echo "Containers:"
    show_non_running_containers
    echo
    echo "Images:"
    show_none_images
    echo
}

confirm_cleanup() {
    if is_true "${DRY_RUN:-0}"; then
        print_header "Dry-run completed" "$BLUE"
        echo "Nothing was deleted."
        return 1
    fi

    if is_true "${AUTO_APPROVE:-0}"; then
        return 0
    fi

    if ! is_interactive; then
        echo "Non-interactive shell detected; preview shown but cleanup not executed."
        echo "Re-run interactively, or set AUTO_APPROVE=1 to proceed without a prompt."
        return 1
    fi

    if (( SELECT_MODE )); then
        read -r -p "Proceed with removing the selected containers/images? This may include running containers or tagged images. [y/N]: " confirm || true
    else
        read -r -p "Proceed with safe cleanup? [y/N]: " confirm || true
    fi

    case "${confirm,,}" in
        y|yes) return 0 ;;
        *)
            print_header "Cleanup cancelled" "$YELLOW"
            echo "Nothing was deleted."
            return 1
            ;;
    esac
}

remove_none_images() {
    local none_images_output image_id repository tag created_since removal_failed=0
    none_images_output="$(list_none_images)"

    if [[ -z "$none_images_output" ]]; then
        echo "[*] No <none>:<none> images found for explicit removal."
        return 0
    fi

    while IFS=$'\t' read -r image_id repository tag created_since; do
        [[ -n "$image_id" ]] || continue
        echo "[*] Removing <none>:<none> image $image_id ..."
        if ! podman rmi -f --ignore "$image_id"; then
            echo "[!] Could not remove image $image_id; it may still be referenced."
            removal_failed=1
        fi
    done <<< "$none_images_output"

    return "$removal_failed"
}

remove_selected_containers() {
    local container_id removal_failed=0

    if (( ${#SELECTED_CONTAINERS[@]} == 0 )); then
        echo "[*] No containers were selected for removal."
        return 0
    fi

    for container_id in "${SELECTED_CONTAINERS[@]}"; do
        echo "[*] Removing container $container_id ..."
        if ! podman rm -f --ignore "$container_id"; then
            echo "[!] Could not remove container $container_id."
            removal_failed=1
        fi
    done

    return "$removal_failed"
}

remove_selected_images() {
    local image_id removal_failed=0

    if (( ${#SELECTED_IMAGES[@]} == 0 )); then
        echo "[*] No images were selected for removal."
        return 0
    fi

    for image_id in "${SELECTED_IMAGES[@]}"; do
        echo "[*] Removing image $image_id ..."
        if ! podman rmi -f --ignore "$image_id"; then
            echo "[!] Could not remove image $image_id; it may still be referenced."
            removal_failed=1
        fi
    done

    return "$removal_failed"
}

parse_args "$@"

if ! have podman; then
    err "'podman' not found. Install it first (see linux_utils/toolchains/bootstrap_toolchains.sh)."
    exit 1
fi

CURRENT_ACTION="checking Podman health"
if ! podman info >/dev/null 2>&1; then
    err "'podman info' failed. Check your Podman setup before running cleanup."
    exit 1
fi

if (( SELECT_MODE )); then
    CURRENT_ACTION="selecting targets in fzf"
    select_targets_tui
fi

print_header "Starting Podman cleanup" "$BLUE"
if (( SELECT_MODE )); then
    echo "fzf selection mode removes only the items you mark, including running containers or tagged images if you choose them."
else
    echo "Safe cleanup removes non-running containers and tries to remove all '<none>:<none>' images."
fi

echo
preview_cleanup

if (( SELECT_MODE )) && (( ${#SELECTED_CONTAINERS[@]} == 0 && ${#SELECTED_IMAGES[@]} == 0 )); then
    print_header "Nothing selected" "$BLUE"
    echo "No containers or images were marked for removal."
    exit 0
fi

if ! confirm_cleanup; then
    exit 0
fi

if (( SELECT_MODE )); then
    selected_container_count=${#SELECTED_CONTAINERS[@]}
    selected_image_count=${#SELECTED_IMAGES[@]}

    CURRENT_ACTION="removing selected containers"
    if ! remove_selected_containers; then
        echo
        echo "[!] Some selected containers could not be removed automatically."
    fi
    echo

    CURRENT_ACTION="removing selected images"
    if ! remove_selected_images; then
        echo
        echo "[!] Some selected images could not be removed automatically."
    fi
    echo

    remaining_selected_containers="$(count_remaining_selected_containers)"
    remaining_selected_images="$(count_remaining_selected_images)"
    selected_containers_removed=$((selected_container_count - remaining_selected_containers))
    selected_images_removed=$((selected_image_count - remaining_selected_images))

    print_header "Podman cleanup completed" "$BLUE"
    echo "Selected containers removed:   $selected_containers_removed"
    echo "Selected images removed:       $selected_images_removed"
    echo "Selected containers remaining: $remaining_selected_containers"
    echo "Selected images remaining:     $remaining_selected_images"
    if (( remaining_selected_images > 0 )); then
        echo "Some selected images are likely still referenced by Podman and could not be removed safely."
    fi
    exit 0
fi

containers_before="$(count_non_running_containers)"
images_before="$(count_none_images)"

if (( containers_before == 0 && images_before == 0 )); then
    print_header "Nothing to clean" "$BLUE"
    exit 0
fi

CURRENT_ACTION="pruning non-running containers"
container_prune_output="$(podman container prune -f 2>&1)"
echo "$container_prune_output"
echo

CURRENT_ACTION="pruning dangling images"
image_prune_output="$(podman image prune -f 2>&1)"
echo "$image_prune_output"
echo

CURRENT_ACTION="removing <none>:<none> images"
if ! remove_none_images; then
    echo
    echo "[!] Some <none>:<none> images could not be removed automatically."
fi
echo

containers_after="$(count_non_running_containers)"
images_after="$(count_none_images)"
containers_removed=$((containers_before - containers_after))
images_removed=$((images_before - images_after))

print_header "Podman cleanup completed" "$BLUE"
echo "Non-running containers removed: $containers_removed"
echo "<none>:<none> images removed:   $images_removed"
echo "Remaining non-running containers: $containers_after"
echo "Remaining <none>:<none> images:   $images_after"
if (( images_after > 0 )); then
    echo "Some remaining <none>:<none> images are likely still referenced by Podman and cannot be safely removed yet."
fi
