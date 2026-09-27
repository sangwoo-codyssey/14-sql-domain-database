# 14 - 정보를 깔끔하게 정리하는 디지털 서랍장 (SQL Domain Database)

> 🚧 **미착수** — 디렉터리·레포 준비만 완료

백엔드 프레임워크 없이, 도메인 테이블을 직접 설계하고(PK/FK/제약조건) 데이터를 넣고
요구사항을 SQL 로 푸는 전 과정. 결과물은 **SQL 파일 3개 + 실행 결과**다.

- 과제 원문: 로컬 `../14-sql-domain-database.md`

## 선택 사항 (미정)

| 항목 | 값 | 비고 |
|---|---|---|
| DB | _미정_ | SQLite / MySQL / PostgreSQL / H2 중 택1 — SQLite 가 설치 부담 0 |
| 도메인 주제 | _미정_ | 최소 4테이블 + 1:N 관계 2개 이상을 낼 수 있는 주제 |
| 접속 도구 | _미정_ | CLI / DBeaver / TablePlus / DataGrip |

`run.sh` 는 **SQLite 를 가정**해 작성돼 있다. 다른 DB 를 고르면 같이 고쳐야 한다.

## 스키마

_(미설계)_ — 확정되면 테이블 목록과 1:N 관계를 여기에 적는다.

| 테이블 | 역할 | PK | FK |
|---|---|---|---|
| _미정_ | | | |

제약조건 최소 요건: `NOT NULL` 1개 이상 · `UNIQUE` 1개 이상 · FK 가 실제로 동작(없는 값 참조 차단)

## 쿼리 범주별 개수 (총 15개 이상)

| 범주 | 필요 | 작성 | 조건 |
|---|---|---|---|
| 기본 조회 | 4+ | 0 | `WHERE` · `ORDER BY` · `LIMIT` 포함 |
| 조인 | 4+ | 0 | `INNER JOIN` 2+ , `LEFT JOIN` 1+ |
| 집계 | 3+ | 0 | `COUNT`/`SUM`/`AVG` 중 2종 + `GROUP BY` |
| 서브쿼리 | 1+ | 0 | |
| 수정·삭제 | 2+ | 0 | `UPDATE` · `DELETE` |
| 인덱스 | 1+ | 0 | `CREATE INDEX` + 적용 이유 1줄 |

각 쿼리에는 "무엇을 확인하는 쿼리인지" 한 줄 주석을 붙인다.
DB 고유 문법을 쓴 쿼리에는 어떤 DB 전용인지 주석으로 명시한다.

## 폴더 구조

```
.
├── sql/
│   ├── 01-schema.sql    # 제출물 1 — CREATE TABLE + PK/FK/제약조건
│   ├── 02-seed.sql      # 제출물 2 — 테이블당 10행 이상 (부모 테이블 먼저)
│   └── 03-queries.sql   # 제출물 3 — 쿼리 15개 + 한 줄 설명
├── results/             # 제출물 4 — 실행 결과 캡처(이미지 또는 텍스트)
├── docs/                # (선택) ERD 다이어그램
├── run.sh
└── README.md
```

## 실행

```bash
./run.sh build    # DB 파일 새로 만들고 01-schema → 02-seed 적용
./run.sh run      # sqlite3 대화형 셸 열기
./run.sh test     # 03-queries.sql 실행하고 결과 출력 (results/ 로 저장 가능)
```

`DB_FILE` 로 DB 경로를, `SQLITE` 로 sqlite3 실행 파일을 바꿀 수 있다.

## 범위 밖 (과제 §7 명시)

- **백엔드 프레임워크 금지** — Spring/Django/Express 로 API·화면을 만들지 않는다
- 뷰(View) · 프로시저 · 트리거 사용하지 않는다
- 정규화 이론을 깊게 파지 않는다 (관계가 자연스럽고 쿼리가 잘 나오는 구조를 목표로)

## 제출물 체크리스트

- [ ] `sql/01-schema.sql` — 스키마 생성 SQL 1개 파일
- [ ] `sql/02-seed.sql` — 샘플 데이터 INSERT SQL 1개 파일 (테이블당 10행 이상)
- [ ] `sql/03-queries.sql` — 쿼리 15개 SQL 1개 파일
- [ ] `results/` — 실행 결과 캡처 폴더
- [ ] (선택) `docs/erd.png` — ERD 다이어그램

## 보너스

- [ ] 같은 요구를 JOIN / 서브쿼리 두 방식으로 풀고 차이 비교
- [ ] 일부러 FK 에러를 내고 왜 막히는지 기록
- [ ] 미니 리포트 — 핵심 지표 3개 정의 + 각각의 SQL
