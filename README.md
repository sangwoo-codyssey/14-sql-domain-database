# 14 - 정보를 깔끔하게 정리하는 디지털 서랍장 (SQL Domain Database)

백엔드 프레임워크 없이, 가계부 도메인의 테이블을 직접 설계하고(PK/FK/제약조건) 데이터를 넣고
요구사항을 SQL 로 푸는 전 과정. 결과물은 **SQL 파일 3개 + 실행 결과**다.

- 과제 원문: 로컬 `../14-sql-domain-database.md`

## 선택 사항

| 항목 | 값 | 비고 |
|---|---|---|
| DB | **MySQL 9.7** | 공식 이미지 `mysql:9.7` (Docker Hub `lts` 태그). Docker Compose 로 띄운다 |
| 도메인 주제 | **가계부** | 회원 · 계좌 · 카테고리 · 거래 내역 · 월 예산 |
| 접속 도구 | **CLI** (컨테이너 안 `mysql`) | 로컬에 MySQL 클라이언트를 설치할 필요가 없다. DBeaver 등으로는 `127.0.0.1:3306` 접속 |
| ERD | **Mermaid** | [`docs/erd.md`](docs/erd.md) (GitHub 에서 바로 렌더) → `./run.sh erd` 로 PNG |

## 스키마

![ERD](docs/erd.png)

| 테이블 | 역할 | PK | FK | 주요 제약 |
|---|---|---|---|---|
| `member` | 회원 | `id` | — | `email` UNIQUE · NOT NULL |
| `category` | 수입/지출 분류 | `id` | — | `name` UNIQUE · `entry_type` ∈ {INCOME, EXPENSE} |
| `account` | 계좌·카드·현금 지갑 | `id` | `member_id → member` | (`member_id`, `name`) UNIQUE · `account_type` ∈ {BANK, CARD, CASH} |
| `ledger_entry` | 거래 내역 (가계부 한 줄) | `id` | `account_id → account` · `category_id → category` | `amount > 0` · `memo` 만 NULL 허용 |
| `budget` | 회원의 월·카테고리별 예산 | `id` | `member_id → member` · `category_id → category` | (`member_id`, `category_id`, `budget_month`) UNIQUE · `budget_month` 는 매월 1일 |

- 테이블 5개, **1:N 관계 5개**(FK 5개).
- 제약조건: `NOT NULL` 22개 컬럼(PK 제외 17개) · `UNIQUE` 4개 · `CHECK` 5개 · FK 5개.
- FK 는 MySQL(InnoDB)이 항상 검사한다 — 없는 부모를 가리키는 INSERT 는 `ERROR 1452`, 자식이 남은 부모의 DELETE 는 `ERROR 1451` 로 막힌다.

## 샘플 데이터

| 테이블 | 행 수 | 비고 |
|---|---|---|
| `member` | 10 | 2명은 계좌 미등록 |
| `category` | 13 | 수입 3 · 지출 10, 2개는 아직 쓰이지 않음 |
| `account` | 12 | 1개는 거래 없음 |
| `ledger_entry` | 47 | 2026-07 ~ 2026-09 |
| `budget` | 12 | 2026-09 10건 · 2026-08 2건 |

부모 테이블부터 넣는다: `member → category → account → ledger_entry → budget`.
`./run.sh check` 결과는 [`results/check.txt`](results/check.txt).

## 쿼리 (16개)

| 범주 | 필요 | 작성 | 쿼리 |
|---|---|---|---|
| 기본 조회 | 4+ | 4 | Q01 기간·금액 조건 TOP 5 · Q02 메모 검색 · Q03 최근 가입자 · Q04 계좌별 최근 거래 |
| 조인 | 4+ (INNER 2+, LEFT 1+) | 4 | Q05 INNER 4테이블 · Q06 INNER 회원-계좌 · Q07 LEFT 계좌 없는 회원 · Q08 LEFT 카테고리별 건수(0 포함) |
| 집계 | 3+ (COUNT/SUM/AVG 2종+, GROUP BY) | 3 | Q09 월별 수입·지출(SUM) · Q10 카테고리별 COUNT·SUM·AVG · Q11 회원별 지출 HAVING |
| 서브쿼리 | 1+ | 2 | Q12 스칼라(평균보다 큰 지출) · Q13 파생 테이블(예산 초과) |
| 수정·삭제 | 2+ | 2 | Q15 UPDATE 재분류 · Q16 DELETE 중복 거래 |
| 인덱스 | 1+ | 1 | Q14 `CREATE INDEX` + 전후 `EXPLAIN` 비교 |

- 모든 쿼리 위에 "무엇을 확인하는 쿼리인지" 한 줄 주석이 있다.
- MySQL 전용 문법(`LIMIT`, `DATE_FORMAT`, `EXPLAIN FORMAT`, `AUTO_INCREMENT`)은 쓴 자리에 주석으로 표기했다.
- 날짜 조건은 `CURDATE()` 대신 리터럴로 고정 — 언제 실행해도 결과가 같다.
- 실행 결과: [`results/03-queries.txt`](results/03-queries.txt) (`./run.sh test --save` 로 재생성).

## 폴더 구조

```
.
├── sql/
│   ├── 01-schema.sql    # 제출물 1 — CREATE TABLE + PK/FK/제약조건
│   ├── 02-seed.sql      # 제출물 2 — 테이블당 10행 이상 (부모 테이블 먼저)
│   └── 03-queries.sql   # 제출물 3 — 쿼리 16개 + 한 줄 설명
├── results/             # 제출물 4 — 실행 결과 텍스트
│   ├── 03-queries.txt   #   ./run.sh test --save
│   └── check.txt        #   ./run.sh check
├── docs/                # (선택) ERD — erd.md(Mermaid 원본) · erd.png
├── compose.yaml         # MySQL 9.7 컨테이너 (127.0.0.1 에만 바인딩)
├── .env.example         # 접속 정보 템플릿 — .env 가 없으면 run.sh 가 복사
├── run.sh
└── README.md
```

## 실행

필요한 것: Docker Desktop (Compose v2). MySQL 클라이언트 설치는 필요 없다.

```bash
./run.sh up           # MySQL 컨테이너 기동 (healthy 까지 대기, 첫 기동은 이미지 다운로드)
./run.sh build        # DB 재생성 → 01-schema → 02-seed
./run.sh test         # build 후 03-queries 실행 결과 출력 (--save 면 results/ 에 저장)
./run.sh check        # 과제 정량 요건 점검 (테이블·PK·FK·NOT NULL·UNIQUE·행 수)
./run.sh run          # mysql 대화형 셸
./run.sh erd          # docs/erd.md → docs/erd.png
./run.sh down [-v]    # 컨테이너 정리 (-v 면 데이터 볼륨까지)
```

- `test` 는 매번 `build` 부터 다시 한다 — 쿼리 파일에 UPDATE/DELETE 가 있어도 몇 번을 돌리든 같은 결과가 나온다.
- 포트를 바꾸려면 `.env` 의 `MYSQL_PORT` 를 고친다.

## 범위 밖 (과제 §7 명시)

- **백엔드 프레임워크 금지** — Spring/Django/Express 로 API·화면을 만들지 않는다
- 뷰(View) · 프로시저 · 트리거 사용하지 않는다
- 정규화 이론을 깊게 파지 않는다 (관계가 자연스럽고 쿼리가 잘 나오는 구조를 목표로)

## 제출물 체크리스트

- [x] `sql/01-schema.sql` — 스키마 생성 SQL 1개 파일
- [x] `sql/02-seed.sql` — 샘플 데이터 INSERT SQL 1개 파일 (테이블당 10행 이상)
- [x] `sql/03-queries.sql` — 쿼리 16개 SQL 1개 파일
- [x] `results/` — 실행 결과 텍스트 폴더
- [x] (선택) `docs/erd.png` — ERD 다이어그램

## 보너스

진행하지 않는다.

- ~~같은 요구를 JOIN / 서브쿼리 두 방식으로 풀고 차이 비교~~
- ~~일부러 FK 에러를 내고 왜 막히는지 기록~~
- ~~미니 리포트 — 핵심 지표 3개 정의 + 각각의 SQL~~
