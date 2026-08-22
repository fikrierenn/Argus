#!/usr/bin/env bash
# Denetci kapisi — BkmArgus PreToolUse hook (matcher: Bash, git commit).
#
# NEDEN VAR:
# phase-review-gate.md hangi degisiklikte hangi denetcinin ZORUNLU oldugunu
# zaten yaziyor. 2026-08-22 oturumunda 6 migration + yeni ekran + endpoint
# yetki degisikligi commit'lendi; yalniz ai-pipeline-reviewer kosuldu.
# Sonradan kosulan digerleri sunlari buldu:
#   - sagalayici ekraninda sir sizdirma yolu (ApiKeyRef -> config yolu)
#   - sql/68 ileri bagimlilik: temiz kurulumda SP hic olusmuyor
#   - sql/75 eski blogu kaldirmadan ekliyor: prompt'ta iki celiskili blok
# Hicbiri "dikkat edersem yakalarim" turu degildi.
#
# NASIL CALISIR:
# Staged dosyalara gore gerekli denetcileri hesaplar. Commit mesajinda
#   [reviewed: sql-sp,security]     -> kosuldu beyani
#   [review-skipped: <gerekce>]     -> bilincli atlama (borc)
# yoksa exit 2 ile BLOKLAR.
#
# Beyan serefe dayanir — ama bilincsiz atlamayi imkansiz kilar. Asil kazanc
# "unuttum"un "bilerek atliyorum, gerekcesi su"ya donusmesidir.
#
# Cikis kodlari: 0 devam · 2 BLOKLA
# Acil bypass: CLAUDE_REVIEW_SKIP=1 (kural ihlali — journal'a yaz)

set -e
[ "${CLAUDE_REVIEW_SKIP:-0}" = "1" ] && exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

input=$(cat)

# JSON cozumu: jq yoksa python. sed fallback'i BILINCLI olarak kaldirildi —
# komut icinde tirnak varsa (heredoc'lu commit mesajlarinin tamami boyle)
# sed ilk tirnakta kesiyor ve [reviewed: ...] beyani hic gorunmuyordu.
# Sonuc: kapi her gercek commit'i bloklardi. Test etmeseydim kullanilamaz
# bir kapi birakmis olacaktim.
if command -v jq >/dev/null 2>&1; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
elif command -v python >/dev/null 2>&1; then
  cmd=$(echo "$input" | python -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || echo "")
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(echo "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || echo "")
else
  cmd="$input"
fi

echo "$cmd" | grep -qE '(^|[[:space:]&;])git[[:space:]]+commit([[:space:]]|$)' || exit 0

staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$staged" ] && exit 0

# Yalniz dokuman/plan degisikligi ise denetci gerekmez
if ! echo "$staged" | grep -qvE '\.(md|txt)$|^docs/|^plans/'; then
  exit 0
fi

# ESLEME DOSYADAN OKUNUR — mekanizma ortak, esleme projeye ozel.
# Her projenin klasor yapisi ve denetci kadrosu farkli: Operax'ta
# ai-pipeline-reviewer ve etl-validator yok, klasorler src/ site/ tools/.
MAP=".claude/review-map.conf"

[ -f "$MAP" ] || exit 0

gerekli=""
neden=""

while IFS= read -r satir; do
  case "$satir" in ""|\#*) continue ;; esac

  etiket=${satir%%::*};   kalan=${satir#*::}
  desen=${kalan%%::*};    aciklama=${kalan#*::}

  if echo "$staged" | grep -qE "$desen"; then
    case " $gerekli " in
      *" $etiket "*) ;;
      *) gerekli="$gerekli $etiket"
         neden="$neden
  - $etiket: $aciklama" ;;
    esac
  fi
done < "$MAP"

[ -z "$gerekli" ] && exit 0

# Beyan var mi
if echo "$cmd" | grep -qE '\[reviewed:[^]]*\]|\[review-skipped:[^]]+\]' \
   || echo "$input" | grep -qE '\[reviewed:[^]]*\]|\[review-skipped:[^]]+\]'; then
  exit 0
fi

cat >&2 <<EOF

╔════════════════════════════════════════════════════════════════════════╗
║  DENETCI KAPISI — commit bloklandi
╚════════════════════════════════════════════════════════════════════════╝

Staged dosyalar su denetcileri ZORUNLU kiliyor (phase-review-gate.md):
$neden

Agent tool ile kosulacaklar:$gerekli
(etiket -> ajan eslemesi icin .claude/review-map.conf)

Bagimsiz olanlari TEK mesajda paralel baslat.

Sonra commit mesajina beyan ekle:
  [reviewed:$(echo $gerekli | tr ' ' ',')]
veya bilincli atliyorsan:
  [review-skipped: <gerekce>]   + TODO.md'ye borc satiri

Neden bu kapi var: 2026-08-22'de bu denetciler atlandi. Sonradan
kosulduklarinda bir sir sizdirma yolu, iki kritik SQL hatasi ve yanlis
ogretilmis bir domain kurali buldular. Hicbiri goz taramasiyla bulunacak
turden degildi.

EOF

exit 2
