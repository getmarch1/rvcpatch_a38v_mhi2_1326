#!/bin/ksh
# RVC-Fullscreen-Patch (Audi A3 8V, MHI2) - Post-Script
# ${2} = Wurzelverzeichnis des Update-Datentraegers (SD-Karte)

PKG_VERSION="0.05"
SHOW_IMAGES=1        # 1 = Statusbilder im Display anzeigen, 0 = aus
FW_CHECK=1           # 1 = nur auf MHI2_ER_AU37x_P5089_MU1326 installieren, 0 = Pruefung aus

MEDIA=${2}
SRC=${MEDIA}/RVCpatch/payload
STATUS=${MEDIA}/RVCpatch/status
APP=/net/mmx/mnt/app
SYS=/net/mmx/mnt/system
DM_DIR=${SYS}/etc/eso/production
IMG_DIR=${APP}/eso/hmi/lsd/images/HMIEarlyAppsEvoHighScale
KZB_DIR=${APP}/eso/hmi/lsd/kzbs/HMISystemEvoHighScale
KZB_LIST="OPS_AU370.kzb OPS_AU371.kzb OPS_AU373.kzb OPS_AU375.kzb"
LOG=${MEDIA}/rvcpatch.log
PLOG=""              # zweites Log ausserhalb der SD-Karte (wird unten gesucht)

# Systemprogramme fuer die Bildanzeige
IMGBIN=/net/mmx/eso/bin/apps/loadandshowimage
DMDT=/net/mmx/eso/bin/apps/dmdt
IMGCFG=/net/mmx/etc/imgprocessing.cfg
IMG_ON=0
FAILIMG=06_fehler.png

# Firmware-Pruefung: Train (19 Byte ab 0x3A0) und MU (4 Byte ab 0x3B9) im EEPROM
E2P_BIN=/net/rcc/usr/apps/modifyE2P
FW_NAME="MHI2_ER_AU37x_P5089_MU1326"
EXP_TRAIN=" 4d 48 49 32 5f 45 52 5f 41 55 33 37 78 5f 50 35 30 38 39"
EXP_MU=" 31 33 32 36"

# ---------------------------------------------------------------- Logging

log() {
    echo "$*" >> ${LOG}
    [ -n "${PLOG}" ] && echo "$*" >> ${PLOG}
}

# Log zusaetzlich in den internen Speicher schreiben (falls beschreibbar)
setup_plog() {
    for d in /HBpersistence/SWDL/RVCpatch /net/rcc/HBpersistence/SWDL/RVCpatch; do
        mkdir -p ${d} > /dev/null 2>&1
        if touch ${d}/.w > /dev/null 2>&1; then
            rm -f ${d}/.w
            PLOG=${d}/rvcpatch.log
            # einfache Begrenzung: ab 64 KB wird das alte Log beiseitegelegt
            if [ -f ${PLOG} ] && [ $(wc -c < ${PLOG}) -gt 65536 ]; then
                mv -f ${PLOG} ${PLOG}.old
            fi
            return 0
        fi
    done
    return 0
}

# Pruefsumme einer Datei (sha1sum, sonst cksum, sonst "n/a")
SUMBIN=""
if type sha1sum > /dev/null 2>&1; then
    SUMBIN="sha1sum"
elif [ -x /net/rcc/usr/bin/sha1sum ]; then
    SUMBIN="/net/rcc/usr/bin/sha1sum"
fi

sumof() {
    [ -f "$1" ] || { echo "fehlt"; return 0; }
    if [ -n "${SUMBIN}" ]; then
        ${SUMBIN} "$1" 2> /dev/null | { read s r; echo "${s:-n/a}"; }
    elif type cksum > /dev/null 2>&1; then
        cksum "$1" 2> /dev/null | { read s z r; echo "${s:-n/a}/${z:-?}"; }
    else
        echo "n/a"
    fi
}

target_of() {
    case $1 in
        displaymanager.json) echo ${DM_DIR}/$1 ;;
        *.png)               echo ${IMG_DIR}/$1 ;;
        *.kzb)               echo ${KZB_DIR}/$1 ;;
    esac
}

# Pruefsummen: Zustand auf dem Geraet im Vergleich zum Paket
log_sums() {
    log "--- Pruefsummen ($1) ---"
    for f in ${SRC}/*; do
        n=${f##*/}
        t=$(target_of ${n})
        [ -n "${t}" ] || continue
        log "  ${n}  system=$(sumof ${t})  paket=$(sumof ${f})"
    done
}

log_info() {
    log "Paketversion: ${PKG_VERSION}"
    log "Datum: $(date 2> /dev/null)"
    log "Medium: ${MEDIA}"
    log "System: $(uname -a 2> /dev/null)"
    if type df > /dev/null 2>&1; then
        log "--- Speicher (df -k) ---"
        for p in ${APP} ${SYS}; do
            log "$(df -k ${p} 2>&1)"
        done
    fi
    [ -n "${PLOG}" ] && log "Zweites Log: ${PLOG}"
}

# ---------------------------------------------------------- Bildanzeige
# Alles hier ist "best effort": Fehler werden ignoriert und duerfen den
# Patch nie beeinflussen. Jeder Aufruf wird nach spaetestens N Sekunden
# beendet, damit nichts haengen bleibt.

limited() {
    t=$1; shift
    "$@" > /dev/null 2>&1 &
    p=$!
    i=0
    while [ ${i} -lt ${t} ] && kill -0 ${p} 2> /dev/null; do
        sleep 1
        i=$((i + 1))
    done
    kill -0 ${p} 2> /dev/null && kill ${p} 2> /dev/null
    return 0
}

show_image() {
    [ "${SHOW_IMAGES}" = "1" ] || return 0
    [ -f "${STATUS}/$1" ] || return 0
    export LIBIMG_CFGFILE=${IMGCFG}
    [ ${IMG_ON} = 1 ] && limited 3 ${IMGBIN} 1 2 3 4 5
    on -f mmx ${IMGBIN} "${STATUS}/$1" > /dev/null 2>&1 &
    sleep 1
    limited 3 on -f mmx ${DMDT} sc 0 -9
    IMG_ON=1
    return 0
}

hide_image() {
    [ ${IMG_ON} = 1 ] || return 0
    export LIBIMG_CFGFILE=${IMGCFG}
    limited 3 ${IMGBIN} 1 2 3 4 5
    limited 3 on -f mmx ${DMDT} sb 0
    IMG_ON=0
    return 0
}

# ------------------------------------------------------ Fehler / Rollback

fail() {
    log "FEHLER: $*"
    log "=== ABGEBROCHEN ==="
    show_image ${FAILIMG}
    sync
    mount -ur ${APP}
    mount -ur ${SYS}
    sleep 8
    hide_image
    exit 1
}

# Rollback: nur wenn schon ueberschrieben wurde
rollback() {
    log "Rollback aus den Sicherungen"
    cp ${DM_DIR}/displaymanager.json.original ${DM_DIR}/displaymanager.json
    cp ${IMG_DIR}_original/* ${IMG_DIR}/
    cp ${KZB_DIR}_original/* ${KZB_DIR}/
    sync
}

# Sicherungen: erst unter temporaerem Namen anlegen, nach vollstaendigem
# Kopieren umbenennen. So gilt eine unterbrochene Sicherung nie als gueltig.
# Vorhandene (fertige) Sicherungen werden NIE ueberschrieben.

backup_file() {
    if [ -f $1.original ]; then
        log "Sicherung vorhanden: $1.original"
        return 0
    fi
    if [ -e $1.original.tmp ]; then
        log "Unvollstaendige Sicherung aus frueherem Lauf entfernt: $1.original.tmp"
        rm -f $1.original.tmp
    fi
    if cp $1 $1.original.tmp && mv $1.original.tmp $1.original; then
        log "Sicherung angelegt: $1.original"
    else
        rm -f $1.original.tmp
        fail "Sicherung $1"
    fi
}

backup_dir() {
    if [ -d $1_original ]; then
        log "Sicherung vorhanden: $1_original"
        return 0
    fi
    if [ -e $1_original.tmp ]; then
        log "Unvollstaendige Sicherung aus frueherem Lauf entfernt: $1_original.tmp"
        rm -rf $1_original.tmp
    fi
    if cp -r $1 $1_original.tmp && mv $1_original.tmp $1_original; then
        log "Sicherung angelegt: $1_original"
    else
        rm -rf $1_original.tmp
        fail "Sicherung $1"
    fi
}

# ------------------------------------------------------ Firmware-Pruefung
# Liest 32 Byte ab 0x3A0 (Train + MU) und vergleicht die Bytes direkt, ohne
# Hilfsprogramme zur Textumwandlung. Nichts wird veraendert.

hex2txt() {
    for b in $*; do
        printf "\\$(printf '%o' 0x${b})" 2> /dev/null
    done
}

check_firmware() {
    if [ "${FW_CHECK}" != "1" ]; then
        log "Firmware-Pruefung deaktiviert (FW_CHECK=0)"
        return 0
    fi
    E2PTMP=/tmp/rvc_e2p.$$
    rm -f ${E2PTMP}
    on -f rcc ${E2P_BIN} r 3A0 32 > ${E2PTMP} 2>&1 &
    p=$!
    i=0
    while [ ${i} -lt 20 ] && kill -0 ${p} 2> /dev/null; do
        sleep 1
        i=$((i + 1))
    done
    kill -0 ${p} 2> /dev/null && kill ${p} 2> /dev/null

    OUT=""
    [ -f ${E2PTMP} ] && OUT=$(cat ${E2PTMP})
    rm -f ${E2PTMP}

    # nur Bytewerte (zwei Hexziffern) uebernehmen, Adressen und Meldungen ueberspringen
    set -f
    n=0; TRAIN=""; MUV=""
    for w in ${OUT}; do
        case ${w} in
            [0-9a-f][0-9a-f])
                n=$((n + 1))
                [ ${n} -le 19 ] && TRAIN="${TRAIN} ${w}"
                [ ${n} -ge 26 ] && [ ${n} -le 29 ] && MUV="${MUV} ${w}"
                ;;
        esac
    done
    set +f

    if [ ${n} -lt 29 ]; then
        log "EEPROM-Rohausgabe: ${OUT}"
        FAILIMG=08_firmware_unbekannt.png
        fail "Firmware konnte nicht gelesen werden (${n} Bytes erhalten), keine Installation"
    fi
    log "Firmware gelesen: Train=$(hex2txt ${TRAIN}) MU=$(hex2txt ${MUV}) (hex:${TRAIN} /${MUV})"
    if [ "${TRAIN}" != "${EXP_TRAIN}" ] || [ "${MUV}" != "${EXP_MU}" ]; then
        FAILIMG=07_firmware_falsch.png
        fail "Firmware ist nicht ${FW_NAME}, keine Installation"
    fi
    log "Firmware-Pruefung ok (${FW_NAME})"
}

# ------------------------------------------------------------------ Start

# SD-Karte schreibbar, Autorun sofort umbenennen (verhindert Update-Schleife, auch bei Abbruch)
mount -uw ${MEDIA}
mv ${MEDIA}/SWDLautorun.txt ${MEDIA}/_SWDLautorun.txt
setup_plog
log "=== RVC-Patch gestartet ==="
log_info
show_image 01_pruefung.png
check_firmware

# 1. Partitionen schreibbar
mount -uw ${APP} && mount -uw ${SYS} || fail "mount -uw app/system"

# Vorab-Pruefungen (nichts wird veraendert, bevor alles stimmt)
[ -f ${SRC}/displaymanager.json ] || fail "displaymanager.json fehlt im Paket"
ls ${SRC}/*.png > /dev/null 2>&1 || fail "keine PNG-Dateien im Paket"
[ -f ${DM_DIR}/displaymanager.json ] || fail "displaymanager.json im System nicht gefunden"
[ -d ${IMG_DIR} ] || fail "Zielordner images fehlt: ${IMG_DIR}"
[ -d ${KZB_DIR} ] || fail "Zielordner kzbs fehlt: ${KZB_DIR}"
for f in ${KZB_LIST}; do
    [ -f ${SRC}/${f} ] || fail "${f} fehlt im Paket"
    [ -f ${KZB_DIR}/${f} ] || fail "${f} im System nicht vorhanden (andere Firmware?)"
done
log "Vorab-Pruefungen ok"
log_sums "vorher"

# 2.-4. Sicherungen
show_image 02_sicherung.png
backup_file ${DM_DIR}/displaymanager.json
backup_dir ${IMG_DIR}
backup_dir ${KZB_DIR}
sync

# 5.-7. Dateien ersetzen
show_image 03_installation.png
cp ${SRC}/displaymanager.json ${DM_DIR}/ || { rollback; fail "Kopieren displaymanager.json"; }
cp ${SRC}/*.png ${IMG_DIR}/ || { rollback; fail "Kopieren PNG"; }
cp ${SRC}/OPS_*.kzb ${KZB_DIR}/ || { rollback; fail "Kopieren KZB"; }
sync

# Kontrolle (nur wenn cmp vorhanden)
show_image 04_kontrolle.png
if type cmp > /dev/null 2>&1; then
    cmp -s ${SRC}/displaymanager.json ${DM_DIR}/displaymanager.json || { rollback; fail "Verify displaymanager.json"; }
    for f in ${SRC}/*.png; do
        cmp -s ${f} ${IMG_DIR}/${f##*/} || { rollback; fail "Verify ${f##*/}"; }
    done
    for f in ${SRC}/OPS_*.kzb; do
        cmp -s ${f} ${KZB_DIR}/${f##*/} || { rollback; fail "Verify ${f##*/}"; }
    done
    log "Verify ok"
else
    log "cmp nicht vorhanden, Verify uebersprungen"
fi
log_sums "nachher"

# Partitionen wieder schreibgeschuetzt
sync
mount -ur ${APP} && mount -ur ${SYS} || log "WARNUNG: mount -ur app/system fehlgeschlagen"

log "=== RVC-Patch erfolgreich ==="
show_image 05_erfolg.png
sync
sleep 6
hide_image
touch /tmp/SWDLScript.Result
