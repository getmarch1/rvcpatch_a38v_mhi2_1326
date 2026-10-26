#!/bin/ksh
# RVC-Fullscreen-Patch (Audi A3 8V, MHI2) - Post-Script
# ${2} = Wurzelverzeichnis des Update-Datentraegers (SD-Karte)

MEDIA=${2}
SRC=${MEDIA}/RVCpatch/payload
APP=/net/mmx/mnt/app
SYS=/net/mmx/mnt/system
DM_DIR=${SYS}/etc/eso/production
IMG_DIR=${APP}/eso/hmi/lsd/images/HMIEarlyAppsEvoHighScale
KZB_DIR=${APP}/eso/hmi/lsd/kzbs/HMISystemEvoHighScale
KZB_LIST="OPS_AU370.kzb OPS_AU371.kzb OPS_AU373.kzb OPS_AU375.kzb"
LOG=${MEDIA}/rvcpatch.log

log() { echo "$*" >> ${LOG}; }

# SD-Karte schreibbar, Autorun sofort umbenennen (verhindert Update-Schleife, auch bei Abbruch)
mount -uw ${MEDIA}
mv ${MEDIA}/SWDLautorun.txt ${MEDIA}/_SWDLautorun.txt
log "=== RVC-Patch gestartet ==="

fail() {
    log "FEHLER: $*"
    log "=== ABGEBROCHEN ==="
    sync
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

# 2.-4. Sicherungen (vorhandene Sicherungen werden NIE ueberschrieben)
if [ -f ${DM_DIR}/displaymanager.json.original ]; then
    log "Sicherung vorhanden: displaymanager.json.original"
else
    cp ${DM_DIR}/displaymanager.json ${DM_DIR}/displaymanager.json.original \
        || { rm -f ${DM_DIR}/displaymanager.json.original; fail "Sicherung displaymanager.json"; }
    log "Sicherung angelegt: displaymanager.json.original"
fi

for d in ${IMG_DIR} ${KZB_DIR}; do
    if [ -d ${d}_original ]; then
        log "Sicherung vorhanden: ${d}_original"
    else
        cp -r ${d} ${d}_original || { rm -rf ${d}_original; fail "Sicherung ${d}"; }
        log "Sicherung angelegt: ${d}_original"
    fi
done
sync

# 5.-7. Dateien ersetzen
cp ${SRC}/displaymanager.json ${DM_DIR}/ || { rollback; fail "Kopieren displaymanager.json"; }
cp ${SRC}/*.png ${IMG_DIR}/ || { rollback; fail "Kopieren PNG"; }
cp ${SRC}/OPS_*.kzb ${KZB_DIR}/ || { rollback; fail "Kopieren KZB"; }
sync

# Kontrolle (nur wenn cmp vorhanden)
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

log "=== RVC-Patch erfolgreich ==="
sync
touch /tmp/SWDLScript.Result
