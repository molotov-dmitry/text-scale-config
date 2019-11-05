#!/bin/bash

set -e

#### Functions =================================================================

showmessage()
{
    local message="$1"

    if tty -s
    then
        echo "${message}"
        read -p "Press [Enter] to continue"
    else
        zenity --info --width 400 --text="${message}"
    fi
}

showquestion()
{
    local message="$1"

    if tty -s
    then
        while true
        do
            read -p "${message} [Y/n] " RESULT

            if [[ -z "${RESULT}" || "${RESULT,,}" == 'y' ]]
            then
                return 0
            fi

            if [[ "${RESULT,,}" == 'n' ]]
            then
                return 1
            fi
        done
    else
        if zenity --question --width 400 --text="${message}"
        then
            return 0
        else
            return 1
        fi
    fi
}

selectvalue()
{
    local title="$1"
    local prompt="$2"
    
    shift
    shift

    local result=''

    if tty -s
    then
        result=''
        
        echo "${prompt}" >&2
        select result in "$@"
        do
            if [[ -z "${REPLY}" ]] || [[ ${REPLY} -gt 0 && ${REPLY} -le $# ]]
            then
                break
            else
                
                continue
            fi
        done
    else
        while true
        do
            result=$(zenity --title="$title" --text="$prompt" --list --column="Options" "$@") || break
            if [[ -n "$result" ]]
            then
                break
            fi
        done
    fi
    
    echo "$result"
}

disableautostart()
{
    showmessage "Configuration completed. You can re-configure text scaling factor by running 'text-scale-config' command"

    mkdir -p "${HOME}/.config/text-scale-config"
    echo "autostart=false" > "${HOME}/.config/text-scale-config/setup-done"
}

getscale()
{
    local defaultdpi=96
    local sizepx="$1"
    local sizemm="$2"
    
    if [[ $sizepx -le 0 ]] || [[ $sizemm -le 0 ]]
    then
        return 1
    fi
    
    local dpi="$(echo "${sizepx} / (${sizemm} / 25.4)" | bc -l)"
    local scalelong="$(echo "${dpi} / 96" | bc -l)"
    local scale="$(LC_NUMERIC=C printf "%.2f" "${scalelong}" | sed '/\./ s/\.\{0,1\}0\{1,\}$//')"
    
    if [[ -z "$scale" || "$scale" == '0' ]]
    then
        return 1
    fi
    
    echo "${scale}"
}

roundscale()
{
    LC_NUMERIC=C printf "%.1f" "$1" | sed '/\./ s/\.\{0,1\}0\{1,\}$//'
}

#### Globals ===================================================================

unset options
declare -a options

options=('1.0' '1.25' '1.5' '2.0')

#### Get displays DPI list =====================================================

while read -r displayinfo
do
    sizepx="$(echo "${displayinfo}" | grep -o '[[:digit:]]\+x[[:digit:]]\+')"
    sizespx=("${sizepx%%x*}" "${sizepx##*x}")

    sizemm=$(echo "${displayinfo}" | grep -o '[[:digit:]]\+mm' | sed 's/mm$//' | tr '\n' 'x' | sed 's/x$//')
    sizesmm=("${sizemm%%x*}" "${sizemm##*x}")

    for i in 0 1
    do
        scale="$(getscale "${sizespx[$i]}" "${sizesmm[$i]}")"
        
        options+=("$scale")
        options+=("$(roundscale "$scale")")
    done
done < <(LC_ALL=C xrandr | grep ' connected')

#### Sort and remove duplicates from scales list ===============================

readarray -t scales < <(for a in "${options[@]}"; do echo "$a"; done | sort -g | uniq)

#### Select and apply scale ====================================================

while true
do
    newscale="$(selectvalue 'Text scaling factor' 'Please select text scaling factor:' "${scales[@]}")"
    
    if [[ -n "${newscale}" ]]
    then
        oldscale="$(gsettings get org.gnome.desktop.interface text-scaling-factor)"
        
        gsettings set org.gnome.desktop.interface text-scaling-factor ${newscale}
        
        if showquestion "Save these settings?" "save" "try another"
        then
            break
        else
            if [[ -n "${oldscale}" ]]
            then
                gsettings set org.gnome.desktop.interface text-scaling-factor ${oldscale}
            else
                gsettings reset org.gnome.desktop.interface text-scaling-factor
            fi
            
            continue
        fi
    fi
    
    break

done

#### Disable autostart =========================================================

disableautostart
