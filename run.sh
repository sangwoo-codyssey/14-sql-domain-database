#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# MySQL 9.7 을 Docker Compose 로 띄운다(compose.yaml). 로컬에 mysql 클라이언트가 없어도 되도록
# 모든 SQL 은 컨테이너 안의 mysql 클라이언트로 실행한다.
SCHEMA=sql/01-schema.sql
SEED=sql/02-seed.sql
QUERIES=sql/03-queries.sql
RESULT=results/03-queries.txt
ERD_SRC=docs/erd.md
ERD_PNG=docs/erd.png
MERMAID_IMAGE="${MERMAID_IMAGE:-minlag/mermaid-cli}"

log() { echo "$@" >&2; }   # 진행 메시지는 stderr — test 결과(stdout)에 섞이지 않게

load_env() {
  if [ ! -f .env ]; then
    cp .env.example .env
    log ".env 가 없어 .env.example 을 복사했습니다."
  fi
  set -a; . ./.env; set +a
}

need_docker() {
  command -v docker &>/dev/null || { log "docker 를 찾을 수 없습니다. Docker Desktop 을 설치하세요."; exit 1; }
  docker info &>/dev/null || { log "Docker 데몬이 꺼져 있습니다. Docker Desktop 을 켜세요 (open -a Docker)."; exit 1; }
}

need_file() {
  [ -f "$1" ] && return
  log "$1 이 아직 없습니다."
  exit 1
}

# 컨테이너 안 mysql 클라이언트. 비밀번호는 MYSQL_PWD 로 넘겨 "command line password" 경고를 피한다.
mysql_in() {
  docker compose exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" db \
    mysql -uroot --default-character-set=utf8mb4 "$@"
}

# 이미 떠 있으면 조용히 넘어가고, 아니면 healthcheck 통과까지 기다린다(첫 기동은 초기화로 수십 초).
ensure_up() {
  need_docker
  load_env
  if [ "$(docker compose ps --status running --services 2>/dev/null)" = "db" ] &&
     docker compose exec -T db mysqladmin ping -h 127.0.0.1 --silent &>/dev/null; then
    return
  fi
  log "MySQL 컨테이너를 띄웁니다..."
  docker compose up -d --wait --wait-timeout 180 >&2
}

# mysql -vvv 출력 정리: 실행 시간은 매번 달라 diff 만 더럽히고,
# 주석만 있는 블록은 "0 rows affected" 문장으로 찍히므로 주석 줄만 남긴다.
tidy() {
  perl -0pe '
    s/ \((?:\d+ min )?\d+(?:\.\d+)? sec\)//g;
    s/-{14}\n((?:--[^\n]*\n)+)-{14}\n\nQuery OK, 0 rows affected\n\n/$1\n/g;
    s/\nBye\n\z/\n/;
  '
}

has_tables() {
  local n
  n=$(mysql_in -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'")
  [ "$n" -gt 0 ]
}

cmd_up() {
  ensure_up
  log "MySQL $(mysql_in -N -e 'SELECT VERSION()') 준비 완료 — 127.0.0.1:${MYSQL_PORT:-3306}, DB '$MYSQL_DATABASE'"
}

cmd_build() {
  ensure_up
  need_file "$SCHEMA"
  # DB 를 통째로 지우고 다시 만든다 — 그래서 스키마 파일에는 CREATE TABLE 만 두면 된다.
  mysql_in -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`;
               CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
  mysql_in "$MYSQL_DATABASE" < "$SCHEMA"
  if [ -f "$SEED" ]; then
    mysql_in "$MYSQL_DATABASE" < "$SEED"
    log "DB '$MYSQL_DATABASE' 재생성 완료 (스키마 + 샘플 데이터)"
  else
    log "DB '$MYSQL_DATABASE' 재생성 완료 (스키마만 — $SEED 없음)"
  fi
}

cmd_run() {
  ensure_up
  has_tables || cmd_build
  log "mysql 셸을 엽니다. SHOW TABLES; / source /sql/03-queries.sql / exit"
  exec docker compose exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" db \
    mysql -uroot --default-character-set=utf8mb4 "$MYSQL_DATABASE"
}

# 03-queries 에 UPDATE/DELETE 가 있으므로 매번 build 부터 — 몇 번을 돌려도 같은 결과가 나온다.
cmd_test() {
  need_file "$QUERIES"
  cmd_build
  local out
  out=$(
    echo "-- ./run.sh test 출력 (MySQL $(mysql_in -N -e 'SELECT VERSION()'), DB '$MYSQL_DATABASE')"
    echo
    mysql_in -t -vvv --comments "$MYSQL_DATABASE" < "$QUERIES" | tidy
  )
  if [ "${1:-}" = "--save" ]; then
    mkdir -p "$(dirname "$RESULT")"
    printf '%s\n' "$out" > "$RESULT"
    log "$RESULT 에 저장했습니다."
  else
    printf '%s\n' "$out"
  fi
}

# 과제의 정량 요건만 센다. 설계가 "좋은지" 는 판단하지 않는다.
cmd_check() {
  ensure_up
  has_tables || { log "테이블이 없습니다. ./run.sh build 먼저."; exit 1; }
  local tables rows="" sql out
  tables=$(mysql_in -N "$MYSQL_DATABASE" -e "
    SELECT TABLE_NAME FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME")
  for t in $tables; do
    rows+="
    UNION ALL
    SELECT CONCAT('행 수: ', '$t', ' (>= 10)'), COUNT(*), CASE WHEN COUNT(*) >= 10 THEN 'PASS' ELSE 'FAIL' END FROM \`$t\`"
  done
  sql="
    SELECT '테이블 수 (>= 4)' AS 항목, COUNT(*) AS 값,
           CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END AS 결과
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
    UNION ALL
    SELECT 'PK 없는 테이블 (= 0)', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM information_schema.TABLES t
    WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_TYPE = 'BASE TABLE'
      AND NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS c
                      WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
                        AND c.CONSTRAINT_TYPE = 'PRIMARY KEY')
    UNION ALL
    SELECT 'FK 제약 수 (>= 2)', COUNT(*), CASE WHEN COUNT(*) >= 2 THEN 'PASS' ELSE 'FAIL' END
    FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE()
    UNION ALL
    SELECT 'NOT NULL 컬럼 수, PK 제외 (>= 1)', COUNT(*), CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND IS_NULLABLE = 'NO' AND COLUMN_KEY <> 'PRI'
    UNION ALL
    SELECT 'UNIQUE 제약 수 (>= 1)', COUNT(*), CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = 'UNIQUE'
    UNION ALL
    SELECT 'FK 검사 켜짐 (foreign_key_checks = 1)', @@foreign_key_checks,
           CASE WHEN @@foreign_key_checks = 1 THEN 'PASS' ELSE 'FAIL' END
    $rows;"
  out=$(mysql_in -t "$MYSQL_DATABASE" -e "$sql")
  echo "$out"
  if grep -q 'FAIL' <<<"$out"; then
    log "요건 미충족 항목이 있습니다."
    exit 1
  fi
}

# docs/erd.md 의 mermaid 블록 → docs/erd.png (mermaid-cli 컨테이너, 첫 실행 때 이미지 다운로드)
cmd_erd() {
  need_docker
  need_file "$ERD_SRC"
  local mmd="docs/.erd.mmd"
  awk '/^```mermaid/{f=1; next} /^```/{f=0} f' "$ERD_SRC" > "$mmd"
  [ -s "$mmd" ] || { rm -f "$mmd"; log "$ERD_SRC 에 \`\`\`mermaid 블록이 없습니다."; exit 1; }
  docker run --rm -u "$(id -u):$(id -g)" -v "$SCRIPT_DIR/docs:/data" "$MERMAID_IMAGE" \
    -i "/data/$(basename "$mmd")" -o "/data/$(basename "$ERD_PNG")" -b white -s 2 >&2
  rm -f "$mmd"
  log "$ERD_PNG 생성 완료"
}

cmd_down() {
  need_docker
  load_env
  if [ "${1:-}" = "-v" ]; then
    docker compose down -v   # 데이터 볼륨까지 삭제
  else
    docker compose down
  fi
}

usage() {
  cat <<USAGE
사용법: $0 <명령>
  up          MySQL 컨테이너 기동 (healthy 까지 대기)
  build       DB 재생성 → 01-schema → 02-seed
  run         mysql 대화형 셸
  test        build 후 03-queries 실행 결과 출력 (--save 면 $RESULT 에 저장)
  check       과제 정량 요건 점검 (테이블·PK·FK·NOT NULL·UNIQUE·행 수)
  erd         $ERD_SRC → $ERD_PNG
  down        컨테이너 중지·삭제 (-v 면 데이터 볼륨까지)
USAGE
}

case "${1:-}" in
  up)    cmd_up ;;
  build) cmd_build ;;
  run)   cmd_run ;;
  test)  cmd_test "${2:-}" ;;
  check) cmd_check ;;
  erd)   cmd_erd ;;
  down)  cmd_down "${2:-}" ;;
  *)     usage; exit 1 ;;
esac
