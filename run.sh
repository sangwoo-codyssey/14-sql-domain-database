#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# SQLite 를 가정한다 (파일 기반 · 서버 불필요 · macOS 기본 제공).
# 다른 DB 로 바꾸면 이 스크립트도 같이 고쳐야 한다. Docker 는 쓰지 않는다.
SQLITE="${SQLITE:-sqlite3}"
DB_FILE="${DB_FILE:-app.db}"
SCHEMA=sql/01-schema.sql
SEED=sql/02-seed.sql
QUERIES=sql/03-queries.sql

check_sqlite() {
  command -v "$SQLITE" &>/dev/null && return
  echo "$SQLITE 를 찾을 수 없습니다. SQLITE 환경변수로 지정하세요." >&2
  exit 1
}

need_file() {
  [ -f "$1" ] && return
  echo "$1 이 아직 없습니다 (미착수)." >&2
  exit 1
}

# FK 는 SQLite 에서 기본 OFF 다. 켜지 않으면 "없는 값 참조가 막혀야 한다"(과제 §4)를
# 만족하지 못하면서도 조용히 통과해버린다 — 그래서 매 실행마다 명시적으로 켠다.
FK_ON="PRAGMA foreign_keys = ON;"

cmd_build() {
  check_sqlite
  need_file "$SCHEMA"
  rm -f "$DB_FILE"
  "$SQLITE" "$DB_FILE" <<SQL
$FK_ON
.read $SCHEMA
SQL
  if [ -f "$SEED" ]; then
    "$SQLITE" "$DB_FILE" <<SQL
$FK_ON
.read $SEED
SQL
    echo "$DB_FILE 생성 완료 (스키마 + 샘플 데이터)"
  else
    echo "$DB_FILE 생성 완료 (스키마만 — $SEED 없음)"
  fi
}

cmd_run() {
  check_sqlite
  [ -f "$DB_FILE" ] || cmd_build
  echo "sqlite3 셸을 엽니다. .tables / .schema 로 확인, .quit 로 종료."
  exec "$SQLITE" -header -column -cmd "$FK_ON" "$DB_FILE"
}

cmd_test() {
  check_sqlite
  need_file "$QUERIES"
  [ -f "$DB_FILE" ] || cmd_build
  "$SQLITE" -header -column "$DB_FILE" <<SQL
$FK_ON
.read $QUERIES
SQL
}

case "${1:-}" in
  build) cmd_build ;;
  run)   cmd_run ;;
  test)  cmd_test ;;
  *)     echo "사용법: $0 {build|run|test}"; exit 1 ;;
esac
