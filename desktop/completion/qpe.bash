# Bash completion for qpe (QR Password Exchanger desktop CLI).

_qpe_complete_contacts() {
    local cur="$1" contact_file contact_name
    local contacts_dir="${QPE_HOME:-$HOME/.qr-password-exchanger}/contacts"
    for contact_file in "$contacts_dir"/*.pub; do
        [[ -f "$contact_file" ]] || continue
        contact_name=${contact_file##*/}
        contact_name=${contact_name%.pub}
        [[ "$contact_name" == "$cur"* ]] && COMPREPLY+=("$contact_name")
    done
}

_qpe() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    COMPREPLY=()

    if (( COMP_CWORD == 1 )); then
        mapfile -t COMPREPLY < <(compgen -W "key send receive contacts help" -- "$cur")
        return
    fi

    case "${COMP_WORDS[1]}" in
        help)
            (( COMP_CWORD == 2 )) && \
                mapfile -t COMPREPLY < <(compgen -W "key send receive contacts" -- "$cur")
            ;;
        send)
            compopt -o filenames
            if [[ "$prev" == --qr ]]; then
                mapfile -t COMPREPLY < <(compgen -f -- "$cur")
            elif [[ "$cur" == -* ]]; then
                mapfile -t COMPREPLY < <(compgen -W "--qr --help" -- "$cur")
            else
                _qpe_complete_contacts "$cur"
                mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -f -- "$cur")
            fi
            ;;
        receive)
            compopt -o filenames
            case "$prev" in
                --name) ;;
                --private-key) mapfile -t COMPREPLY < <(compgen -f -- "$cur") ;;
                *)
                    if [[ "$cur" == -* ]]; then
                        mapfile -t COMPREPLY < <(compgen -W "--name --private-key --help" -- "$cur")
                    else
                        mapfile -t COMPREPLY < <(compgen -f -- "$cur")
                    fi
                    ;;
            esac
            ;;
        key|contacts)
            [[ "$cur" == -* ]] && mapfile -t COMPREPLY < <(compgen -W "--help" -- "$cur")
            ;;
    esac
}

complete -F _qpe qpe
