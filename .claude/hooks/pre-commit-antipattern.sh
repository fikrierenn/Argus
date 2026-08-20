#!/usr/bin/env bash
# Pre-commit antipattern scan — BkmArgus PreToolUse hook.
#
# Tetikleyici: settings.json PreToolUse, matcher = "Bash", command ~= "git commit".
# Staged .cs/.cshtml/.sql/.json dosyalarinda kritik antipattern arar, bulursa exit 2 ile commit'i BLOKLAR.
#
# Cikis kodlari:
#   0 -> commit devam etsin
#   2 -> commit BLOKLA (stderr mesaji user'a gider)
#
# Acil bypass: CLAUDE_PRECOMMIT_SKIP=1 (kural ihlali — journal'a yaz)

set -e
[ "${CLAUDE_PRECOMMIT_SKIP:-0}" = "1" ] && exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
else
  cmd=$(echo "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

echo "$cmd" | grep -qE '(^|[[:space:]&;])git[[:space:]]+commit([[:space:]]|$)' || exit 0

staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$staged" ] && exit 0

targets=$(echo "$staged" | grep -E '\.(cs|cshtml|sql|json)$' || true)
[ -z "$targets" ] && exit 0

found=()

for f in $targets; do
  [ -f "$f" ] || continue

  # ---------- C# ----------
  if [[ "$f" == *.cs ]]; then
    grep -HnE '^\s*catch\s*\{|^\s*catch\s*\(\s*\)\s*\{' "$f" 2>/dev/null \
      && found+=("$f: bare catch (silent failure) — logger zorunlu")

    grep -Hn 'new HttpClient()' "$f" 2>/dev/null | grep -v '^\s*//' \
      && found+=("$f: new HttpClient() -> IHttpClientFactory")

    grep -HnE '(TempData\[[^]]*\]\s*=\s*[^;]*ex\.Message|Results\.(BadRequest|Json)\([^;]*ex\.Message|return[^;]*ex\.Message)' "$f" 2>/dev/null \
      && found+=("$f: ex.Message user'a sizinti -> generic Turkce mesaj + logger")

    grep -HnE 'async void ' "$f" 2>/dev/null | grep -v 'event' | grep -v '^\s*//' \
      && found+=("$f: async void (event handler harici yasak)")

    grep -Hn 'DataTable\.Compute' "$f" 2>/dev/null \
      && found+=("$f: DataTable.Compute yasak (formula injection)")

    # SP-first ihlali: Web katmaninda inline SQL
    if [[ "$f" == src/BkmArgus.Web/* ]]; then
      grep -HniE '(QueryAsync|QuerySingleAsync|ExecuteAsync|CommandText)\s*[(=]\s*[@$"]*"[[:space:]]*(SELECT|INSERT|UPDATE|DELETE|MERGE)[[:space:]]' "$f" 2>/dev/null \
        && found+=("$f: Web katmaninda inline SQL (SP-first ihlali — architecture.md 2)")
    fi

    # SQL string concat
    grep -HnE '(ExecuteAsync|QueryAsync|QuerySingleAsync)\s*\(\s*"[^"]*"\s*\+' "$f" 2>/dev/null \
      && found+=("$f: SQL string concat (injection — parametre kullan)")

    grep -Hn 'Console\.WriteLine' "$f" 2>/dev/null | grep -v '^\s*//' | grep -v 'BkmArgus.Installer' \
      && found+=("$f: Console.WriteLine -> ILogger (Installer harici)")
  fi

  # ---------- Razor ----------
  if [[ "$f" == *.cshtml ]]; then
    grep -HnE '@Html\.Raw\(' "$f" 2>/dev/null \
      && found+=("$f: @Html.Raw XSS riski (auto-encode veya <script type=application/json> kullan)")

    grep -HnE 'style="[^"]*(color|font-|background-color|border-color|box-shadow)' "$f" 2>/dev/null \
      && found+=("$f: inline style (renk/font) -> Tailwind class (razor-conventions.md)")

    # Yeni sayfa yetkisiz mi
    if grep -q '^@page' "$f" 2>/dev/null; then
      case "$f" in
        */Account/Login.cshtml|*/Account/Logout.cshtml|*/Account/AccessDenied.cshtml|*/Error.cshtml|*/Shared/*|*_View*) ;;
        *) grep -q 'Authorize' "$f" 2>/dev/null || found+=("$f: @page var ama [Authorize] yok (security-principles.md 4)") ;;
      esac
    fi
  fi

  # ---------- SQL ----------
  if [[ "$f" == *.sql ]]; then
    grep -HnE '\bGETDATE\s*\(\s*\)' "$f" 2>/dev/null \
      && found+=("$f: GETDATE() -> SYSDATETIME() (sql-conventions.md 2)")

    grep -HniE '\b(datetime)\b[^2(]' "$f" 2>/dev/null | grep -viE 'datetime2|datetimeoffset|--' \
      && found+=("$f: datetime tipi -> datetime2(0)")

    grep -HniE '\b(float|real)\b' "$f" 2>/dev/null | grep -v '\-\-' \
      && found+=("$f: float/real -> decimal(18,3) miktar / decimal(18,4) para")

    grep -HniE 'SELECT[[:space:]]+\*' "$f" 2>/dev/null | grep -v '\-\-' \
      && found+=("$f: SELECT * yasak — kolonlari acikca yaz")

    # src.* view degistirme girisimi
    grep -HniE '(ALTER|CREATE OR ALTER|DROP)[[:space:]]+VIEW[[:space:]]+\[?src\]?\.' "$f" 2>/dev/null \
      && found+=("$f: src.* view degistiriliyor — DOKUNULMAZ (architecture.md 4)")

    # Yazma yapan SP'de TRY-CATCH yoklugu
    if grep -qiE 'CREATE OR ALTER[[:space:]]+PROCEDURE' "$f" 2>/dev/null; then
      if grep -qiE '^\s*(INSERT|UPDATE|DELETE|MERGE)\b' "$f" 2>/dev/null; then
        grep -qi 'BEGIN TRY' "$f" 2>/dev/null || found+=("$f: yazma yapan SP'de BEGIN TRY/CATCH yok (sql-conventions.md 4)")
        grep -qi 'XACT_ABORT' "$f" 2>/dev/null || found+=("$f: SET XACT_ABORT ON eksik (sql-conventions.md 4)")
      fi
    fi
  fi

  # ---------- Sir (tum tipler) ----------
  grep -HnE '(Password\s*=\s*["'\''][A-Za-z0-9!@#$%^&*+._-]{3,}|Password=[A-Za-z0-9!@#$%^&*+._-]{4,})' "$f" 2>/dev/null \
    | grep -v 'Password=\$' | grep -v '\.example' | grep -v 'Password=""' \
    && found+=("$f: hardcoded sifre — appsettings.Local.json / env var kullan")

  grep -HnE '(sk-ant-api[0-9]{2}-|AIza[0-9A-Za-z_-]{20,}|xoxb-[0-9]{8,})' "$f" 2>/dev/null \
    && found+=("$f: API key hardcoded — ANAHTARI IPTAL ET + appsettings.Local.json'a tasi")
done

if [ ${#found[@]} -gt 0 ]; then
  echo "=== PRE-COMMIT ANTIPATTERN SCAN: BLOKLANDI ===" >&2
  for i in "${found[@]}"; do echo "  X $i" >&2; done
  echo "" >&2
  echo "Commit iptal. Once duzelt, sonra tekrar commit'le." >&2
  echo "Override: CLAUDE_PRECOMMIT_SKIP=1 (kural ihlali — journal'a yaz)." >&2
  exit 2
fi

exit 0
