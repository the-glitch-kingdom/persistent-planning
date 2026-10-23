#!/bin/bash
# detect-stack.sh — Auto-detect project stack
# Outputs a JSON object with detected stack info to stdout
# Usage: bash detect-stack.sh [project-root]

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT" || exit 1

CYAN='\033[36m'; RESET='\033[0m'
log() { printf '%b\n' "${CYAN}[detect]${RESET} $*" >&2; }

# ── Language Detection ──────────────────────────────────────────────────────
detect_language() {
    local langs=()

    [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "Pipfile" ] \
        && langs+=("python")
    [ -f "package.json" ] \
        && langs+=("javascript")
    find . -maxdepth 3 -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -q . \
        && langs+=("typescript")
    [ -f "go.mod" ] \
        && langs+=("go")
    [ -f "pom.xml" ] || [ -f "build.gradle" ] \
        && langs+=("java")
    [ -f "Cargo.toml" ] \
        && langs+=("rust")
    [ -f "composer.json" ] \
        && langs+=("php")
    [ -f "Gemfile" ] \
        && langs+=("ruby")

    # Primary = first detected, fallback = unknown
    if [ ${#langs[@]} -eq 0 ]; then
        echo "unknown"
    else
        echo "${langs[0]}"
    fi
}

# ── Framework Detection ─────────────────────────────────────────────────────
detect_framework() {
    local lang="$1"

    case "$lang" in
        python)
            grep -r "fastapi\|FastAPI" requirements.txt pyproject.toml setup.py 2>/dev/null | grep -q . && echo "fastapi" && return
            grep -r "django\|Django" requirements.txt pyproject.toml setup.py 2>/dev/null | grep -q . && echo "django" && return
            grep -r "flask\|Flask" requirements.txt pyproject.toml setup.py 2>/dev/null | grep -q . && echo "flask" && return
            echo "python-generic"
            ;;
        javascript|typescript)
            [ -f "next.config.js" ] || [ -f "next.config.ts" ] && echo "nextjs" && return
            grep -q '"next"' package.json 2>/dev/null && echo "nextjs" && return
            grep -q '"nuxt"' package.json 2>/dev/null && echo "nuxtjs" && return
            grep -q '"@nestjs/core"' package.json 2>/dev/null && echo "nestjs" && return
            grep -q '"express"' package.json 2>/dev/null && echo "express" && return
            grep -q '"react"' package.json 2>/dev/null && echo "react" && return
            grep -q '"vue"' package.json 2>/dev/null && echo "vue" && return
            grep -q '"svelte"' package.json 2>/dev/null && echo "svelte" && return
            echo "node-generic"
            ;;
        go)
            grep -r "gin-gonic\|github.com/gin" go.mod 2>/dev/null | grep -q . && echo "gin" && return
            grep -r "echo\|labstack/echo" go.mod 2>/dev/null | grep -q . && echo "echo" && return
            grep -r "chi\|go-chi" go.mod 2>/dev/null | grep -q . && echo "chi" && return
            echo "go-stdlib"
            ;;
        java)
            grep -r "spring-boot\|springframework" pom.xml build.gradle 2>/dev/null | grep -q . && echo "spring-boot" && return
            echo "java-generic"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ── Database Detection ──────────────────────────────────────────────────────
detect_database() {
    # Check docker-compose
    for f in docker-compose.yml docker-compose.yaml docker-compose.dev.yml; do
        [ -f "$f" ] && {
            grep -qi "postgres\|postgresql" "$f" && echo "postgresql" && return
            grep -qi "mysql\|mariadb" "$f" && echo "mysql" && return
            grep -qi "mongo\|mongodb" "$f" && echo "mongodb" && return
            grep -qi "redis" "$f" && echo "redis" && return
            grep -qi "sqlite" "$f" && echo "sqlite" && return
        }
    done
    # Check env files
    for f in .env .env.example .env.local .env.development; do
        [ -f "$f" ] && {
            grep -qi "DATABASE_URL.*postgres" "$f" && echo "postgresql" && return
            grep -qi "DATABASE_URL.*mysql" "$f" && echo "mysql" && return
            grep -qi "DATABASE_URL.*sqlite" "$f" && echo "sqlite" && return
            grep -qi "MONGO_URL\|MONGODB" "$f" && echo "mongodb" && return
        }
    done
    # Check requirements/package.json
    grep -r "psycopg\|asyncpg\|pg\b" requirements.txt pyproject.toml package.json 2>/dev/null | grep -q . && echo "postgresql" && return
    grep -r "pymysql\|mysql2\|mysql-connector" requirements.txt pyproject.toml package.json 2>/dev/null | grep -q . && echo "mysql" && return
    grep -r "motor\|pymongo\|mongoose" requirements.txt pyproject.toml package.json 2>/dev/null | grep -q . && echo "mongodb" && return
    echo "unknown"
}

# ── ORM Detection ───────────────────────────────────────────────────────────
detect_orm() {
    grep -r "sqlalchemy\|SQLAlchemy" requirements.txt pyproject.toml 2>/dev/null | grep -q . && echo "sqlalchemy" && return
    grep -r "alembic" requirements.txt pyproject.toml 2>/dev/null | grep -q . && echo "sqlalchemy+alembic" && return
    [ -f "prisma/schema.prisma" ] || find . -maxdepth 3 -name "schema.prisma" 2>/dev/null | grep -q . && echo "prisma" && return
    grep -r "typeorm\|TypeORM" package.json 2>/dev/null | grep -q . && echo "typeorm" && return
    grep -r "sequelize\|Sequelize" package.json 2>/dev/null | grep -q . && echo "sequelize" && return
    grep -r "django.db.models" requirements.txt pyproject.toml 2>/dev/null | grep -q . && echo "django-orm" && return
    grep -r "drizzle-orm" package.json 2>/dev/null | grep -q . && echo "drizzle" && return
    grep -r "mongoose" package.json 2>/dev/null | grep -q . && echo "mongoose" && return
    echo "unknown"
}

# ── Infrastructure Detection ────────────────────────────────────────────────
detect_infra() {
    local infra=()
    for f in docker-compose.yml docker-compose.yaml docker-compose.dev.yml; do
        [ -f "$f" ] && { infra+=("docker-compose"); break; }
    done
    [ -f "Dockerfile" ] || find . -maxdepth 2 -name "Dockerfile*" 2>/dev/null | grep -q . && infra+=("docker")
    [ -f ".github/workflows" ] || find . -maxdepth 3 -path "*/.github/workflows/*.yml" 2>/dev/null | grep -q . && infra+=("github-actions")
    find . -maxdepth 3 -name "nginx.conf" -o -name "*.nginx" 2>/dev/null | grep -q . && infra+=("nginx")
    find . -maxdepth 3 -name "Caddyfile" 2>/dev/null | grep -q . && infra+=("caddy")
    find . -maxdepth 3 -name "*.tf" 2>/dev/null | grep -q . && infra+=("terraform")
    [ -f "fly.toml" ] && infra+=("fly.io")
    [ -f "render.yaml" ] && infra+=("render")
    [ -f "railway.json" ] || [ -f "railway.toml" ] && infra+=("railway")
    [ -f "vercel.json" ] && infra+=("vercel")
    [ -f "netlify.toml" ] && infra+=("netlify")
    [ -f "heroku.yml" ] || [ -f "Procfile" ] && infra+=("heroku")

    if [ ${#infra[@]} -eq 0 ]; then
        echo "none"
    else
        local IFS=','
        echo "${infra[*]}"
    fi
}

# ── Package Manager Detection ───────────────────────────────────────────────
detect_package_manager() {
    [ -f "pnpm-lock.yaml" ] && echo "pnpm" && return
    [ -f "yarn.lock" ] && echo "yarn" && return
    [ -f "package-lock.json" ] && echo "npm" && return
    [ -f "bun.lockb" ] && echo "bun" && return
    [ -f "Pipfile.lock" ] && echo "pipenv" && return
    [ -f "poetry.lock" ] && echo "poetry" && return
    [ -f "requirements.txt" ] && echo "pip" && return
    [ -f "go.mod" ] && echo "go-modules" && return
    [ -f "Cargo.toml" ] && echo "cargo" && return
    [ -f "Gemfile.lock" ] && echo "bundler" && return
    echo "unknown"
}

# ── Auth Detection ──────────────────────────────────────────────────────────
detect_auth() {
    grep -r "supabase\|@supabase" requirements.txt pyproject.toml package.json 2>/dev/null | grep -q . && echo "supabase" && return
    grep -r "next-auth\|NextAuth\|auth\.js" package.json 2>/dev/null | grep -q . && echo "next-auth" && return
    grep -r "passport\|passportjs" package.json 2>/dev/null | grep -q . && echo "passport" && return
    grep -r "python-jose\|PyJWT\|fastapi-users" requirements.txt pyproject.toml 2>/dev/null | grep -q . && echo "jwt" && return
    grep -r "clerk\|@clerk" package.json 2>/dev/null | grep -q . && echo "clerk" && return
    grep -r "auth0\|@auth0" package.json 2>/dev/null | grep -q . && echo "auth0" && return
    grep -r "keycloak" requirements.txt pyproject.toml package.json 2>/dev/null | grep -q . && echo "keycloak" && return
    echo "unknown"
}

# ── Project Name ─────────────────────────────────────────────────────────────
detect_name() {
    # package.json
    if [ -f "package.json" ]; then
        name=$(python3 -c "import json,sys; d=json.load(open('package.json')); print(d.get('name',''))" 2>/dev/null)
        [ -n "$name" ] && echo "$name" && return
    fi
    # pyproject.toml
    if [ -f "pyproject.toml" ]; then
        name=$(grep -E '^name\s*=' pyproject.toml | head -1 | sed 's/.*=\s*"\(.*\)"/\1/')
        [ -n "$name" ] && echo "$name" && return
    fi
    # Directory name
    basename "$PROJECT_ROOT"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    log "Detecting stack in: $PROJECT_ROOT"

    LANG=$(detect_language)
    FRAMEWORK=$(detect_framework "$LANG")
    DATABASE=$(detect_database)
    ORM=$(detect_orm)
    INFRA=$(detect_infra)
    PKG_MGR=$(detect_package_manager)
    AUTH=$(detect_auth)
    NAME=$(detect_name)
    SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    log "Stack: $LANG / $FRAMEWORK / $DATABASE / $ORM"

    # Output JSON
    cat <<EOF
{
  "name": "$NAME",
  "slug": "$SLUG",
  "language": "$LANG",
  "framework": "$FRAMEWORK",
  "database": "$DATABASE",
  "orm": "$ORM",
  "auth": "$AUTH",
  "package_manager": "$PKG_MGR",
  "infrastructure": "$INFRA",
  "project_root": "$PROJECT_ROOT"
}
EOF
}

main
