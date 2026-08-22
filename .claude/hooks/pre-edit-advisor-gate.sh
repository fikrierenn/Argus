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

# ESLEME DOSYADAN OKUNUR — mekanizma ortak, esleme projeye ozel.
# Operax'a tasirken ogrenildi: BkmArgus'un 'bkmargus-*' danismanlari orada
# yok, hook kapi olmayan bir danismani isaret ediyordu. Mekanizmayi core,
# eslemeyi local yapan ayrim buradan dogdu.
MAP=".claude/advisor-map.conf"

[ -f "$MAP" ] || exit 0   # esleme yoksa kapi calismaz (sessiz gecer)

alan=""; danisman=""; gerekce=""

while IFS= read -r satir; do
  case "$satir" in ""|\#*) continue ;; esac

  a=${satir%%::*};            kalan=${satir#*::}
  desenler=${kalan%%::*};     kalan=${kalan#*::}
  d=${kalan%%::*};            g=${kalan#*::}

  # set -f: dosya adi genislemesini KAPAT. Kapatilmazsa kabuk 'sql/*.sql'
  # desenini sql/ altindaki 77 gercek dosyaya acar ve desen olarak eslesmez.
  # '*' ile baslayan desenler eslesme bulamadigi icin duz kaliyordu — yani
  # kapi kazara calisiyordu. Test etmeseydim gorunmezdi.
  eski=$IFS; IFS=','; set -f
  for desen in $desenler; do
    IFS=$eski
    case "$norm" in
      $desen) alan="$a"; danisman="$d"; gerekce="$g"; break 2 ;;
    esac
    IFS=','
  done
  IFS=$eski; set +f
done < "$MAP"

[ -z "$alan" ] && exit 0

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
