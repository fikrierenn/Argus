#!/usr/bin/env bash
# Danisman kapisi — BkmArgus PreToolUse hook (matcher: Edit|Write|MultiEdit).
#
# NEDEN VAR:
# advisor-skills.md zaten "danisilmadan yazilan is EKSIK sayilir" diyor.
# Yetmedi — 2026-08-22 oturumunda 6 migration, bir ekran ve bir AI zinciri
# yazildi; danisman yalniz birine soruldu. Sonrasinda bagimsiz denetim
# bir sir sizdirma yolu, iki kritik SQL hatasi ve YANLIS ogretilmis bir
# domain kurali buldu. Kural metni davranisi degistirmedi; kapi degistirir.
#
# NASIL CALISIR:
# Bir alana (sql, AI, ekran, ETL, risk) BU OTURUMDA ILK KEZ dokunulurken
# exit 2 ile BLOKLAR ve hangi danismana danisilacagini soyler. Danisildiktan
# sonra isaret dosyasi birakilir ve ayni alan serbest kalir.
#
#   Skill(bkmargus-sp-first)  ->  touch .git/bkm-advisor-marks/sql
#
# Isaretler .git altinda tutulur: commit'e girmez, klon basina ayridir,
# session-start.sh her oturum basinda temizler.
#
# Cikis kodlari:
#   0 -> devam
#   2 -> BLOKLA (stderr mesaji ana ajana gider)
#
# Acil bypass: CLAUDE_ADVISOR_SKIP=1 (kural ihlali — journal'a yaz)

set -e
[ "${CLAUDE_ADVISOR_SKIP:-0}" = "1" ] && exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
else
  path=$(echo "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

[ -z "$path" ] && exit 0

# Ters bolu -> duz bolu (Windows yollari)
norm=$(echo "$path" | tr '\\' '/')

MARKS=".git/bkm-advisor-marks"
mkdir -p "$MARKS"

alan=""
danisman=""
gerekce=""

case "$norm" in
  sql/*.sql|*/sql/*.sql)
    alan="sql"
    danisman="sql-migration-writer  (yeni migration/sema)  ·  bkmargus-sp-first  (SP yazimi)"
    gerekce="Idempotency, ileri bagimlilik, acik transaction, THROW araligi, Turkce parametre sozlesmesi."
    ;;
  *BkmArgus.AiWorker/*|*/Skills/*|*ai_*.sql|*learning*.sql|*skill*.sql)
    alan="ai"
    danisman="bkmargus-ai-worker"
    gerekce="Kademeli maliyet (LLM son care), prompt DB'de, halusinasyon kapisi, insan onayi, job idempotency."
    ;;
  *Features/*.cshtml|*Features/*.cshtml.cs)
    alan="ekran"
    danisman="screen-ux-standard"
    gerekce="Form akisi, bos durum, hata geri bildirimi, [Authorize] policy, Turkce UI."
    ;;
  *etl*|*Etl*|*rpt_*|*_snapshot*)
    alan="etl"
    danisman="bkmargus-etl"
    gerekce="Gunluk snapshot kurali, idempotency kaniti, src.* alias, ehAltDepo=0, veri kalitesi kapisi."
    ;;
  *risk*|*Risk*)
    alan="risk"
    danisman="bkmargus-risk-model"
    gerekce="Esik/agirlik, yanlis pozitif-negatif dengesi, eskalasyon, geriye donuk karsilastirilabilirlik."
    ;;
  *)
    exit 0
    ;;
esac

# Bu alana bu oturumda zaten danisildiysa gec
[ -f "$MARKS/$alan" ] && exit 0

cat >&2 <<EOF

╔════════════════════════════════════════════════════════════════════════╗
║  DANISMAN KAPISI — '$alan' alanina bu oturumda ILK dokunus
╚════════════════════════════════════════════════════════════════════════╝

Dosya   : $norm
Danisman: $danisman

Neden   : $gerekce

work-protocol.md adim 1: ONCE DANIS, sonra yaz.
Kural metni yeterli olmadi (2026-08-22: 6 migration yazildi, danisilmadi;
denetim bir sir sizdirma yolu ve iki kritik SQL hatasi buldu).

YAPILACAK:
  1) Skill tool ile yukaridaki danismani cagir
  2) Sonra serbest birak:  touch $MARKS/$alan
  3) Edit'i tekrarla

Alan disi acil durum: CLAUDE_ADVISOR_SKIP=1 (journal'a gerekce yaz)

EOF

exit 2
