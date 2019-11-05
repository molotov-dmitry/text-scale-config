#!/bin/bash

set -e

function showmessage()
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

function showquestion()
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

function selectvalue()
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
        select result in "${options[@]}"
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
            result=$(zenity --title="$title" --text="$prompt" --list --column="Options" "${options[@]}") || break
            if [[ -n "$result" ]]
            then
                break
            fi
        done
    fi
    
    echo "$result"
}

function disableautostart()
{
    showmessage "Configuration completed. You can re-configure text scaling factor by running 'text-scale-config' command"

    mkdir -p "${HOME}/.config/text-scale-config"
    echo "autostart=false" > "${HOME}/.config/text-scale-config/setup-done"
}

displayinfo="$(xrandr --current | grep ' connected' | head -n1)"
Xaxis=$(echo "${displayinfo}" | awk '{print $4}' | cut -d '+' -f 1 | cut -d 'x' -f 1)
Yaxis=$(echo "${displayinfo}" | awk '{print $4}' | cut -d '+' -f 1 | cut -d 'x' -f 2)

Xsize=$(echo "${displayinfo}" | grep -o '[[:digit:]]*mm' | head -n1 | sed 's/mm$//')
Ysize=$(echo "${displayinfo}" | grep -o '[[:digit:]]*mm' | tail -n1 | sed 's/mm$//')

Xdpi="$(echo "${Xaxis} / (${Xsize} / 25.4)" | bc -l)"
Ydpi="$(echo "${Yaxis} / (${Ysize} / 25.4)" | bc -l)"

Xscalelong=$(echo "${Xdpi} / 96" | bc -l)
Yscalelong=$(echo "${Ydpi} / 96" | bc -l)

Xscale=$(LC_NUMERIC=C printf "%.2f" "${Xscalelong}")
Yscale=$(LC_NUMERIC=C printf "%.2f" "${Yscalelong}")

Xscaleshort=$(LC_NUMERIC=C printf "%.1f" "${Xscalelong}")
Yscaleshort=$(LC_NUMERIC=C printf "%.1f" "${Yscalelong}")

unset options
declare -a options

options=('1.0')

if [[ -n "$Xscale" ]]
then
    options+=("${Xscale}")
fi

if [[ -n "$Yscale" && "${Yscale}" != "${Xscale}" ]]
then
    options+=("${YScale}")
fi

if [[ -n "$Xscaleshort" && "${Xscaleshort}0" != "${Xscale}" ]]
then
    options+=("${Xscaleshort}")
fi

if [[ -n "$Yscaleshort" && "${Yscaleshort}" != "${Xscaleshort}" && "${Yscaleshort}0" != "${Yscale}" ]]
then
    options+=("${Yscaleshort}")
fi

while true
do
    newscale="$(selectvalue 'Text scaling factor' 'Please select text scaling factor:' "${options[@]}")"
    
    if [[ -n "${newscale}" ]]
    then
        oldscale="$(gsettings get org.gnome.desktop.interface text-scaling-factor)"
        
        echo gsettings set org.gnome.desktop.interface text-scaling-factor ${newscale}
        
        if showquestion "Save these settings?" "save" "try another"
        then
            break
        else
            if [[ -n "${oldscale}" ]]
            then
                echo gsettings set org.gnome.desktop.interface text-scaling-factor ${oldscale}
            else
                echo gsettings reset org.gnome.desktop.interface text-scaling-factor
            fi
            
            continue
        fi
    fi
    
    break

done

disableautostart
