#!/bin/bash
# ==============================================================================
#  ⚡ FULLDNSTUNEL DATA CENTER v3.0 — Motor propio + Gestor HWID + Multi-Protocolo
#  Creado y personalizado por REYDIA8910
#  Instalador y panel en un solo archivo. Debian 10+/Ubuntu 20.04+ (apt).
#  Uso:  bash reydiatunnel.sh      → instala (1ra vez) y abre el panel
#        reydiatunnel              → abre el panel
#        reydiatunnel --cleanup    → corta sesiones vencidas (lo corre cron solo)
# ==============================================================================

VERSION="3.0"

# ───────── TU GITHUB ─────────
REPO_BIN="https://github.com/REYDIA8910/FULLDNSTUNEL/releases/latest/download"
REPO_SCRIPT="https://raw.githubusercontent.com/REYDIA8910/FULLDNSTUNEL/main/reydiatunnel.sh"
# ──────────────────────────────────────────────────────

CONF_DIR="/etc/reydiatunnel"
CONF="$CONF_DIR/reydiatunnel.conf"
DB="$CONF_DIR/hwid_db.txt"
KEY_DIR="$CONF_DIR/keys"
ROUTES="$CONF_DIR/routes.json"
OPT_DIR="/opt/reydiatunnel"
BIN_DIR="$OPT_DIR/bin"
SELF="/usr/local/bin/reydiatunnel"
LIMITS="/etc/security/limits.d/reydiatunnel.conf"

R=$'\e[1;31m'; G=$'\e[1;32m'; Y=$'\e[1;33m'; C=$'\e[1;36m'
M=$'\e[1;35m'; W=$'\e[1;37m'; B=$'\e[1;34m'; N=$'\e[0m'
BGC=$'\e[46;30;1m'

[[ $EUID -ne 0 ]] && { echo "${R}Ejecuta como root (sudo -i)${N}"; exit 1; }

case "$(uname -m)" in
    x86_64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) ARCH=amd64 ;;
esac

declare -A ON

# ══════════════════════════ UTILIDADES ══════════════════════════
pause() { read -rp "  ${Y}Enter para continuar...${N}" _; }
ok()    { echo "  ${G}[✔]${N} $*"; }
warn()  { echo "  ${Y}[!]${N} $*"; }
fail()  { echo "  ${R}[✘]${N} $*"; }
line()  { echo "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"; }
sline() { echo "${C}──────────────────────────────────────────────────────────────────${N}"; }

get_ip() {
    curl -s4 --max-time 5 ifconfig.me 2>/dev/null \
    || curl -s4 --max-time 5 api.ipify.org 2>/dev/null \
    || hostname -I | awk '{print $1}'
}

load_conf() {
    DOMAIN=""; TARGET_PORT=22; SOCKS_PORT=1080; MTU=700
    P_DNSTT=5300; P_VAY=5301; P_SLIP=5302; SERVER_IP=""
    RESOLVER="8.8.8.8:53:0"; VAY_RTYPE="caa"
    [[ -f $CONF ]] && source "$CONF"
    if [[ -z $SERVER_IP ]]; then SERVER_IP=$(get_ip); fi
}

save_conf() {
    mkdir -p "$CONF_DIR"
    cat > "$CONF" <<EOF
DOMAIN="$DOMAIN"
TARGET_PORT="$TARGET_PORT"
SOCKS_PORT="$SOCKS_PORT"
MTU="$MTU"
P_DNSTT="$P_DNSTT"
P_VAY="$P_VAY"
P_SLIP="$P_SLIP"
SERVER_IP="$SERVER_IP"
RESOLVER="$RESOLVER"
VAY_RTYPE="$VAY_RTYPE"
EOF
    chmod 600 "$CONF"
}

svc() { systemctl is-active --quiet "reydiatunnel-$1" 2>/dev/null && echo "${G}ON${N}" || echo "${R}OFF${N}"; }

compute_online() {
    ON=()
    while read -r u c; do
        [[ -n $u ]] && ON[$u]=$c
    done < <(ps -eo user:32=,args= | awk '$1!="root" && $2=="sshd:" {c[$1]++} END{for(u in c) print u,c[u]}')
}

days_left() {   # $1 = fecha YYYY-MM-DD
    echo $(( ( $(date -d "$1" +%s) - $(date -d "$(date +%F)" +%s) ) / 86400 ))
}

exp_millis() {  # $1 = fecha YYYY-MM-DD → epoch en milisegundos para ConfigExporter v28
    echo $(( $(date -d "$1 23:59:59" +%s) * 1000 ))
}

# ══════════════════════════ PANEL PRINCIPAL ══════════════════════════
dashboard() {
    clear
    load_conf
    compute_online
    local today total=0 expd=0 onl=0 h n e m s t p pr
    today=$(date +%F)
    if [[ -f $DB ]]; then
        while IFS='|' read -r h n e m s t p pr; do
            [[ -z $h ]] && continue
            total=$((total+1))
            [[ ! "$e" > "$today" ]] && expd=$((expd+1))
            onl=$((onl + ${ON[$h]:-0}))
        done < "$DB"
    fi
    local os cpus ram cpu disk
    os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")
    cpus=$(nproc)
    ram=$(free -m | awk '/Mem/{printf "%d/%dMB (%.0f%%)",$3,$2,$3*100/$2}')
    cpu=$(top -bn1 | awk '/Cpu\(s\)/{printf "%.1f", $2+$4}')
    disk=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')

    echo "${BGC}       ⚡⚡⚡  FULLDNSTUNEL DATA CENTER  ✦  REYDIA8910  ⚡⚡⚡       ${N}"
    echo
    echo " ${C}◈${N} ONLINES: ${G}${onl}${N}  ${C}◈${N} VENCIDOS: ${R}${expd}${N}  ${C}◈${N} TOTAL: ${Y}${total}${N}"
    echo " ${C}◈${N} S.O: ${W}${os}${N}  ${C}◈${N} CPU's: ${W}${cpus}${N}"
    echo " ${C}◈${N} IP: ${M}${SERVER_IP}${N}  ${C}◈${N} FECHA: ${W}$(date '+%d/%m/%Y-%H:%M')${N}"
    line
    echo " ${Y}Key:${N} ${G}Verified${N} ${C}[ FULLDNSTUNEL v${VERSION} ]${N}  ${C}Dominio:${N} ${W}${DOMAIN:-sin configurar}${N}"
    line
    echo " ${C}◈${N} SSH destino : ${W}127.0.0.1:${TARGET_PORT}${N}   ${C}◈${N} MTU: ${W}${MTU}${N}   ${C}◈${N} VayDNS Record: ${W}${VAY_RTYPE}${N}"
    echo " ${C}◈${N} DNS-Router :53 $(svc dnsrouter)   ${C}◈${N} VayDNS :${P_VAY} $(svc vaydns)"
    echo " ${C}◈${N} DNSTT/Noiz :${P_DNSTT} $(svc dnstt)   ${C}◈${N} Slipstream :${P_SLIP} $(svc slipstream)"
    line
    echo " ${C}◈${N} RAM: ${W}${ram}${N}  ${C}◈${N} CPU: ${W}${cpu}%${N}  ${C}◈${N} DISCO: ${W}${disk}${N}"
    line
    echo " ${R}[${W}01${R}]${N} ${C}◈${N} CREAR HWID  ${G}(elige protocolo + link slipnet:// y reydiatunnel://)${N}"
    echo " ${R}[${W}02${R}]${N} ${C}◈${N} CREAR USUARIO MANUAL  ${G}(elige protocolo individual o combo)${N}"
    echo " ${R}[${W}03${R}]${N} ${C}◈${N} CREAR USUARIOS EN LOTE  ${G}(elige protocolo + exporta TXT)${N}"
    echo " ${R}[${W}04${R}]${N} ${C}◈${N} LISTA DE CLIENTES  ${G}(online / protocolo / vencimientos)${N}"
    echo " ${R}[${W}05${R}]${N} ${C}◈${N} EDITAR  ${G}(clave / límite / vencimiento / protocolo)${N}"
    echo " ${R}[${W}06${R}]${N} ${C}◈${N} RENOVAR"
    echo " ${R}[${W}07${R}]${N} ${C}◈${N} SUSPENDER / REACTIVAR"
    echo " ${R}[${W}08${R}]${N} ${C}◈${N} ELIMINAR"
    echo " ${R}[${W}09${R}]${N} ${C}◈${N} ELIMINAR VENCIDOS"
    echo " ${R}[${W}10${R}]${N} ${C}◈${N} GENERAR LINK slipnet:// o reydiatunnel://  ${G}(elige protocolo)${N}"
    echo " ${R}[${W}11${R}]${N} ${C}◈${N} REINICIAR TÚNELES"
    echo " ${R}[${W}12${R}]${N} ${C}◈${N} AJUSTES  ${G}(dominio / MTU / puerto destino / record VayDNS)${N}"
    echo " ${R}[${W}13${R}]${N} ${C}◈${N} INSTALAR / REPARAR / ACTUALIZAR MOTORES"
    echo " ${R}[${W}14${R}]${N} ${C}◈${N} ACTUALIZAR SCRIPT DESDE GITHUB"
    echo " ${R}[${W}00${R}]${N} ${C}◈${N} ${R}[ SALIR ]${N}"
    line
}

# ══════════════════════════ USUARIOS (HWID + MANUAL) ══════════════════════════
valid_hwid()  { [[ "$1" =~ ^[A-Za-z0-9]{6,32}$ ]]; }
valid_uname() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{2,31}$ ]]; }
valid_id()    { [[ "$1" =~ ^[A-Za-z0-9_-]{3,32}$ ]]; }
valid_limit() { [[ "$1" =~ ^[0-9]{1,3}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 999 )); }
valid_days()  { [[ "$1" =~ ^[0-9]{1,4}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 3650 )); }
valid_pass()  { [[ "$1" =~ ^[A-Za-z0-9@#%+=._-]{4,32}$ ]]; }
rand_pass()   { tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' </dev/urandom | head -c 8; }

db_get() { grep "^$1|" "$DB" 2>/dev/null | head -1; }
is_foreign() { id "$1" &>/dev/null && [[ -z $(db_get "$1") ]]; }

create_user() {   # $1=id $2=nombre $3=fecha_exp [$4=clave]
    local nologin; nologin=$(command -v nologin || echo /usr/sbin/nologin)
    if id "$1" &>/dev/null; then
        usermod -U -e "$3" "$1" || return 1
        [[ -n $4 ]] && echo "$1:$4" | chpasswd
    else
        { useradd -M -s "$nologin" -e "$3" -c "$2" "$1" 2>/dev/null \
          || useradd --badname -M -s "$nologin" -e "$3" -c "$2" "$1"; } || return 1
        echo "$1:${4:-$1}" | chpasswd
    fi
}

set_limit() {     # $1=id $2=max
    touch "$LIMITS"
    sed -i "/^$1[[:space:]]/d" "$LIMITS"
    echo "$1 hard maxlogins $((10#$2))" >> "$LIMITS"
}

db_set() {        # id nombre exp max estado [tipo] [clave] [proto]
    touch "$DB"; chmod 600 "$DB"
    local old tipo pass pr
    old=$(db_get "$1")
    IFS='|' read -r _ _ _ _ _ tipo pass pr <<< "$old"
    tipo=${6:-${tipo:-HWID}}
    [[ $# -ge 7 ]] && pass=$7
    pr=${8:-${pr:-vaydns}}
    sed -i "/^$1|/d" "$DB"
    echo "$1|$2|$3|$4|$5|$tipo|$pass|$pr" >> "$DB"
}

user_card() {     # id nombre exp lim tipo clave [proto]
    echo "    ${C}Usuario:${N}      $1"
    if [[ "$5" == "MANUAL" ]]; then echo "    ${C}Contraseña:${N}   $6"
    else echo "    ${C}Contraseña:${N}   (igual al HWID)"; fi
    echo "    ${C}Cliente:${N}      $2"
    echo "    ${C}Vence:${N}        $3  ($(days_left "$3") días)"
    echo "    ${C}Límite:${N}       $4 conexión(es) simultánea(s)"
    [[ -n $7 ]] && echo "    ${C}Protocolo:${N}    $7"
}

add_client() {
    clear; echo "${BGC}        🔑  AUTORIZAR NUEVO DISPOSITIVO (HWID)        ${N}"; echo
    choose_proto || return
    read -rp "  HWID del dispositivo: " h
    h=$(echo "$h" | tr -d '[:space:]')
    valid_hwid "$h" || { fail "HWID inválido (solo letras/números, 6-32)"; pause; return; }
    is_foreign "$h" && { fail "Ese nombre ya existe en el sistema (no es de FULLDNSTUNEL)"; pause; return; }
    read -rp "  Nombre / referencia del cliente: " name
    name=${name//|/ }; name=${name:-cliente}
    read -rp "  Días de vigencia [30]: " d; d=${d:-30}
    valid_days "$d" || { fail "Días inválidos (1-3650)"; pause; return; }
    read -rp "  Límite de dispositivos simultáneos (1-999) [1]: " m; m=${m:-1}
    valid_limit "$m" || { fail "Límite inválido (1-999)"; pause; return; }
    d=$((10#$d)); m=$((10#$m))

    local exp; exp=$(date -d "+$d days" +%F)
    create_user "$h" "$name" "$exp" "$h" || { fail "No se pudo crear el usuario"; pause; return; }
    set_limit "$h" "$m"
    db_set "$h" "$name" "$exp" "$m" ACTIVO HWID "" "$PROTO"
    echo; ok "Dispositivo autorizado"
    user_card "$h" "$name" "$exp" "$m" HWID "" "$(proto_title)"
    echo; generate_uri "$h" "" "$PROTO" "$exp" "HWID" "$name"
    pause
}

add_manual() {
    clear; echo "${BGC}        👤  CREAR USUARIO MANUAL (usuario + contraseña)        ${N}"; echo
    choose_proto || return
    read -rp "  Usuario (minúsculas/números, 3-32): " u
    valid_uname "$u" || { fail "Usuario inválido (minúsculas, números, _ -; empieza con letra)"; pause; return; }
    is_foreign "$u" && { fail "Ese usuario ya existe en el sistema (no es de FULLDNSTUNEL)"; pause; return; }
    read -rp "  Contraseña [Enter = generar]: " p; p=${p:-$(rand_pass)}
    valid_pass "$p" || { fail "Contraseña inválida (4-32 caracteres: letras, números y @#%+=._-)"; pause; return; }
    read -rp "  Nombre / referencia [Enter = usuario]: " name
    name=${name//|/ }; name=${name:-$u}
    read -rp "  Días de vigencia [30]: " d; d=${d:-30}
    valid_days "$d" || { fail "Días inválidos (1-3650)"; pause; return; }
    read -rp "  Límite de conexiones simultáneas (1-999) [1]: " m; m=${m:-1}
    valid_limit "$m" || { fail "Límite inválido (1-999)"; pause; return; }
    d=$((10#$d)); m=$((10#$m))

    local exp; exp=$(date -d "+$d days" +%F)
    create_user "$u" "$name" "$exp" "$p" || { fail "No se pudo crear el usuario"; pause; return; }
    set_limit "$u" "$m"
    db_set "$u" "$name" "$exp" "$m" ACTIVO MANUAL "$p" "$PROTO"
    echo; ok "Usuario creado"
    user_card "$u" "$name" "$exp" "$m" MANUAL "$p" "$(proto_title)"
    echo; generate_uri "$u" "$p" "$PROTO" "$exp" "MANUAL" "$name"
    pause
}

add_bulk() {
    clear; echo "${BGC}        📦  CREAR USUARIOS EN LOTE        ${N}"; echo
    choose_proto || return
    read -rp "  Prefijo (ej. rey → rey001, rey002...): " pre
    [[ "$pre" =~ ^[a-z][a-z0-9_-]{1,20}$ ]] || { fail "Prefijo inválido (minúsculas/números, empieza con letra)"; pause; return; }
    read -rp "  Cantidad (1-200): " q
    { [[ "$q" =~ ^[0-9]{1,3}$ ]] && (( 10#$q >= 1 && 10#$q <= 200 )); } || { fail "Cantidad inválida (1-200)"; pause; return; }
    read -rp "  Días de vigencia [30]: " d; d=${d:-30}
    valid_days "$d" || { fail "Días inválidos (1-3650)"; pause; return; }
    read -rp "  Límite por usuario (1-999) [1]: " m; m=${m:-1}
    valid_limit "$m" || { fail "Límite inválido (1-999)"; pause; return; }
    q=$((10#$q)); d=$((10#$d)); m=$((10#$m))

    local exp out i=0 made=0 u p
    exp=$(date -d "+$d days" +%F)
    out="/root/lote_${pre}_$(date +%Y%m%d_%H%M%S).txt"
    : > "$out"; chmod 600 "$out"
    echo
    printf "${C}%-20s %-12s %-11s %-5s %s${N}\n" USUARIO CLAVE VENCE LIM PROTOCOLO
    sline
    while (( made < q && i < 9999 )); do
        i=$((i+1)); u=$(printf "%s%03d" "$pre" "$i")
        id "$u" &>/dev/null && continue
        [[ -n $(db_get "$u") ]] && continue
        p=$(rand_pass)
        create_user "$u" "$u" "$exp" "$p" || continue
        set_limit "$u" "$m"
        db_set "$u" "$u" "$exp" "$m" ACTIVO MANUAL "$p" "$PROTO"
        printf "%-20s %-12s %-11s %-5s %s\n" "$u" "$p" "$exp" "$m" "$PROTO"
        bulk_links "$u" "$p" "$exp" "$m" >> "$out"
        made=$((made+1))
    done
    echo; ok "$made usuario(s) creados"
    ok "Lista con links guardada en: ${W}$out${N}"
    pause
}

list_clients() {
    clear; echo "${BGC}        📊  CLIENTES REGISTRADOS        ${N}"; echo
    load_conf; compute_online
    if [[ ! -s $DB ]]; then warn "No hay usuarios registrados."; pause; return; fi
    read -rp "  Filtro (Enter = todos): " f
    echo
    printf "${C}%-17s %-6s %-10s %-10s %-10s %-11s %-5s %-4s %-4s %s${N}\n" USUARIO/HWID TIPO CLAVE PROTO CLIENTE VENCE DÍAS LIM ONL ESTADO
    sline
    local today h n e m s t p pr dl st pv shown=0
    today=$(date +%F)
    while IFS='|' read -r h n e m s t p pr; do
        [[ -z $h ]] && continue
        [[ -n $f && "$h|$n|$pr" != *"$f"* ]] && continue
        t=${t:-HWID}; pr=${pr:-vaydns}
        if [[ $t == MANUAL ]]; then pv=$p; else pv="-"; fi
        dl=$(days_left "$e")
        if [[ "$s" == "SUSPENDIDO" ]]; then st="${Y}SUSPENDIDO${N}"
        elif [[ ! "$e" > "$today" ]]; then st="${R}VENCIDO${N}"
        else st="${G}ACTIVO${N}"; fi
        printf "%-17s %-6s %-10s %-10s %-10s %-11s %-5s %-4s %-4s %s\n" "${h:0:17}" "$t" "${pv:0:10}" "${pr:0:10}" "${n:0:10}" "$e" "$dl" "$m" "${ON[$h]:-0}" "$st"
        shown=$((shown+1))
    done < "$DB"
    echo; echo "  ${C}Mostrando:${N} $shown"
    pause
}

edit_client() {
    clear; echo "${BGC}        ✏  EDITAR USUARIO / HWID        ${N}"; echo
    read -rp "  Usuario o HWID: " h
    local rec; rec=$(db_get "$h")
    [[ -z $rec ]] && { fail "No registrado en FULLDNSTUNEL"; pause; return; }
    local n e m s t p pr
    IFS='|' read -r _ n e m s t p pr <<< "$rec"; t=${t:-HWID}; pr=${pr:-vaydns}
    echo
    user_card "$h" "$n" "$e" "$m" "$t" "$p" "$pr"
    echo
    echo "  1) Cambiar contraseña  (solo usuarios MANUAL)"
    echo "  2) Cambiar límite de conexiones (1-999)"
    echo "  3) Cambiar vencimiento (días desde hoy, o fecha AAAA-MM-DD)"
    echo "  4) Cambiar nombre / referencia"
    echo "  5) Cambiar protocolo y generar nuevo link"
    echo "  0) Volver"
    read -rp "  Opción: " o
    case $o in
        1)  [[ $t != MANUAL ]] && { warn "Un HWID siempre usa su propio ID como contraseña."; pause; return; }
            read -rp "  Nueva contraseña [Enter = generar]: " np; np=${np:-$(rand_pass)}
            valid_pass "$np" || { fail "Contraseña inválida"; pause; return; }
            echo "$h:$np" | chpasswd && db_set "$h" "$n" "$e" "$m" "$s" MANUAL "$np" "$pr"
            ok "Contraseña cambiada: ${W}$np${N}" ;;
        2)  read -rp "  Nuevo límite (1-999): " nm
            valid_limit "$nm" || { fail "Límite inválido"; pause; return; }
            nm=$((10#$nm)); set_limit "$h" "$nm"; db_set "$h" "$n" "$e" "$nm" "$s" "$t" "$p" "$pr"
            ok "Límite: $nm" ;;
        3)  read -rp "  Días desde hoy o fecha: " v
            local ne
            if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$v" >/dev/null 2>&1; then ne=$(date -d "$v" +%F)
            elif valid_days "$v"; then ne=$(date -d "+$((10#$v)) days" +%F)
            else fail "Valor inválido"; pause; return; fi
            usermod -e "$ne" "$h" && db_set "$h" "$n" "$ne" "$m" "$s" "$t" "$p" "$pr"
            ok "Vence: $ne" ;;
        4)  read -rp "  Nuevo nombre: " nn; nn=${nn//|/ }
            [[ -n $nn ]] && db_set "$h" "$nn" "$e" "$m" "$s" "$t" "$p" "$pr" && ok "Nombre actualizado" ;;
        5)  echo; choose_proto || return
            db_set "$h" "$n" "$e" "$m" "$s" "$t" "$p" "$PROTO"
            ok "Protocolo actualizado: $(proto_title)"
            echo; generate_uri "$h" "$p" "$PROTO" "$e" "$t" "$n" ;;
        *)  return ;;
    esac
    pause
}

renew_client() {
    clear; echo "${BGC}        🔄  RENOVAR        ${N}"; echo
    read -rp "  Usuario o HWID: " h
    local rec; rec=$(db_get "$h")
    [[ -z $rec ]] && { fail "No registrado en FULLDNSTUNEL"; pause; return; }
    local n e m s t p pr
    IFS='|' read -r _ n e m s t p pr <<< "$rec"
    read -rp "  Días a sumar [30]: " d; d=${d:-30}
    valid_days "$d" || { fail "Días inválidos (1-3650)"; pause; return; }
    local base today; today=$(date +%F)
    if [[ "$e" > "$today" ]]; then base="$e"; else base="$today"; fi
    local newexp; newexp=$(date -d "$base +$((10#$d)) days" +%F)
    create_user "$h" "$n" "$newexp"
    db_set "$h" "$n" "$newexp" "$m" "ACTIVO" "$t" "$p" "$pr"
    ok "Renovado hasta ${W}$newexp${N}"
    pause
}

toggle_client() {
    clear; echo "${BGC}        🚫  SUSPENDER / REACTIVAR        ${N}"; echo
    read -rp "  Usuario o HWID: " h
    local rec; rec=$(db_get "$h")
    [[ -z $rec ]] && { fail "No registrado en FULLDNSTUNEL"; pause; return; }
    local n e m s t p pr
    IFS='|' read -r _ n e m s t p pr <<< "$rec"
    if [[ "$s" == "SUSPENDIDO" ]]; then
        create_user "$h" "$n" "$e"
        db_set "$h" "$n" "$e" "$m" "ACTIVO" "$t" "$p" "$pr"
        ok "$h reactivado"
    else
        usermod -L "$h" 2>/dev/null
        pkill -KILL -u "$h" 2>/dev/null
        db_set "$h" "$n" "$e" "$m" "SUSPENDIDO" "$t" "$p" "$pr"
        ok "$h suspendido y desconectado en vivo"
    fi
    pause
}

remove_one() {    # $1 = id (quita usuario del sistema y de la base)
    pkill -KILL -u "$1" 2>/dev/null
    userdel -f "$1" 2>/dev/null
    sed -i "/^$1|/d" "$DB" 2>/dev/null
    sed -i "/^$1[[:space:]]/d" "$LIMITS" 2>/dev/null
}

delete_client() {
    clear; echo "${BGC}        🗑  ELIMINAR USUARIO / HWID        ${N}"; echo
    read -rp "  Usuario o HWID a eliminar: " h
    valid_id "$h" || { fail "Valor inválido"; pause; return; }
    [[ -z $(db_get "$h") ]] && { fail "No registrado en FULLDNSTUNEL (no lo toco)"; pause; return; }
    remove_one "$h"
    ok "$h eliminado y desconectado"
    pause
}

purge_expired() {
    clear; echo "${BGC}        🧹  ELIMINAR VENCIDOS        ${N}"; echo
    [[ -s $DB ]] || { warn "No hay usuarios registrados."; pause; return; }
    local today h n e m s t p pr list=()
    today=$(date +%F)
    while IFS='|' read -r h n e m s t p pr; do
        [[ -z $h ]] && continue
        [[ ! "$e" > "$today" ]] && list+=("$h")
    done < "$DB"
    if [[ ${#list[@]} -eq 0 ]]; then ok "No hay vencidos."; pause; return; fi
    echo "  Vencidos (${#list[@]}): ${list[*]}"
    read -rp "  ¿Eliminar todos? [y/N]: " c
    if [[ $c == y || $c == Y ]]; then
        for h in "${list[@]}"; do remove_one "$h"; done
        ok "${#list[@]} usuario(s) eliminados"
    fi
    pause
}

cleanup() {
    [[ -f $DB ]] || return
    local today h n e m s t p pr; today=$(date +%F)
    while IFS='|' read -r h n e m s t p pr; do
        [[ -z $h ]] && continue
        if [[ ! "$e" > "$today" || "$s" == "SUSPENDIDO" ]]; then
            pkill -KILL -u "$h" 2>/dev/null
        fi
    done < "$DB"
}

# ══════════════════════════ PROTOCOLOS + LINK slipnet:// y reydiatunnel:// ══════════════════════════
PROTOS=(
    "vaydns|VayDNS + SSH (KCP/CAA)|vaydns_ssh|vs|vaydns.pub|vaydns|0"
    "dnstt|DNSTT + SSH (Noise)|dnstt_ssh|ts|dnstt.pub|dnstt|0"
    "noizdns|NoizDNS + SSH (Stealth)|sayedns_ssh|ts|dnstt.pub|dnstt|1"
    "slipstream|Slipstream + SSH (QUIC)|slipstream_ssh|ss||slipstream|0"
    "ssh|SSH Directo (TCP :22)|ssh|||ssh|0"
    "vaydns_socks|VayDNS + SOCKS5|vaydns|vs|vaydns.pub|vaydns|0"
    "dnstt_socks|DNSTT + SOCKS5|dnstt|ts|dnstt.pub|dnstt|0"
    "noizdns_socks|NoizDNS + SOCKS5 (Stealth)|sayedns|ts|dnstt.pub|dnstt|1"
    "slipstream_socks|Slipstream + SOCKS5 (QUIC)|ss|
