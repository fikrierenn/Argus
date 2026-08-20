#!/usr/bin/env bash
# SessionStart hook — BkmArgus. Her oturum basinda calisir.
# stdout Claude'a additionalContext olarak gider.

set -e
REPO="${CLAUDE_PROJECT_DIR:-D:/Dev/BkmArgus}"
cd "$REPO" 2>/dev/null || exit 0

echo "## BkmArgus — Oturum Basi Ozet"
echo ""

echo "### Son 3 gun commit"
git log --since='3 days ago' --oneline 2>/dev/null | head -10 || echo "(commit yok)"
echo ""

echo "### Uncommitted"
count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "$count dosya"
if [ "$count" -gt 15 ]; then
    echo "UYARI: 15 dosya esigi asildi — yeni ise baslamadan commit-split (.claude/rules/commit-discipline.md)."
fi
unpushed=$(git log --oneline @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ' || echo 0)
[ "$unpushed" != "0" ] && echo "$unpushed commit push edilmemis"
echo ""

echo "### Guvenlik on-kontrol"
leak=0
if git ls-files 2>/dev/null | grep -qx '.claude/settings.local.json'; then
    echo "- KRITIK: .claude/settings.local.json git'te takipli (connection string tasir)"; leak=1
fi
for f in $(git ls-files 'src/*/appsettings.json' 2>/dev/null); do
    if grep -qE '(Password=[A-Za-z0-9!@#$%^&*._-]{4,}|sk-ant-api|AIza[0-9A-Za-z_-]{20,})' "$f" 2>/dev/null; then
        echo "- KRITIK: $f icinde plain-text sir"; leak=1
    fi
done
[ "$leak" = "0" ] && echo "- Takipli dosyalarda sir yok"
echo ""

echo "### Planlar"
active=$(find plans -maxdepth 1 -name '[0-9]*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
archived=$(find plans/archive -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
echo "- Aktif: $active · Arsiv: $archived"
stale=$(find plans -maxdepth 1 -name '[0-9]*.md' -type f -mtime +14 2>/dev/null)
if [ -n "$stale" ]; then
    echo "- 14+ gun stale plan var — yeniden isit veya arsivle:"
    printf '%s\n' "$stale" | head -3 | sed 's/^/  /'
fi
echo ""

if [ -f TODO.md ]; then
    echo "### Acik TODO (ilk 10)"
    grep -E '^\[ \]|^- \[ \]' TODO.md 2>/dev/null | head -10
    echo ""
fi

echo "### Kod sagligi"
over=$(find src -name '*.cs' -type f -not -path '*/obj/*' -not -path '*/bin/*' -exec wc -l {} + 2>/dev/null | awk '$1 > 500 && $2 != "total"' | sort -rn)
n=$(printf '%s\n' "$over" | grep -c '^[[:space:]]*[0-9]' || true)
if [ "$n" -gt 0 ]; then
    echo "- C# 500+ satir: $n dosya (split borcu)"
    printf '%s\n' "$over" | head -3 | sed 's/^/  /'
else
    echo "- C# 500 hard-limit: temiz"
fi
razor=$(find src -name '*.cshtml' -type f -exec wc -l {} + 2>/dev/null | awk '$1 > 500 && $2 != "total"' | sort -rn | head -2)
[ -n "$razor" ] && printf -- "- Razor 500+ satir:\n%s\n" "$(printf '%s\n' "$razor" | sed 's/^/  /')"
inline=$(grep -ro 'style="' src/BkmArgus.Web/Features 2>/dev/null | wc -l | tr -d ' ')
echo "- Inline style (.cshtml): $inline olusum"
raw=$(grep -ro '@Html.Raw' src/BkmArgus.Web/Features 2>/dev/null | wc -l | tr -d ' ')
echo "- @Html.Raw: $raw olusum"
echo ""

echo "### Son journal"
last=$(ls -t docs/journal/*.md 2>/dev/null | head -1)
if [ -n "$last" ]; then
    mt=$(stat -c '%Y' "$last" 2>/dev/null || echo 0)
    age=$(( ( $(date +%s) - mt ) / 86400 ))
    echo "$last ($age gun once)"
    [ "$age" -ge 2 ] && echo "UYARI: journal $age gun eski — stale claim riski (.claude/rules/todo-verification.md)"
    echo ""
    tail -25 "$last"
else
    echo "(journal yok — oturum sonu /handoff ile olustur)"
fi
echo ""

echo "### Kritik kurallar"
echo "- Mimari: .claude/rules/architecture.md (SP-first, src.* dokunulmaz, 8 sema)"
echo "- SQL: .claude/rules/sql-conventions.md (Ingilizce tablo / Turkce SP parametresi)"
echo "- AI: .claude/rules/ai-layer.md (kademeli maliyet, insan onayi)"
echo "- ETL: .claude/rules/etl-discipline.md (gunluk snapshot, idempotency)"
echo "- Guvenlik: .claude/rules/security-principles.md (RBAC, sir yonetimi)"
echo "- Is dongusu: .claude/rules/work-protocol.md (Danis -> Yap -> Kontrol -> Smoke)"

exit 0
