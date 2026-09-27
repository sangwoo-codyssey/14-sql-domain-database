# 14 - 정보를 깔끔하게 정리하는 디지털 서랍장 (SQL Domain Database)

> 🚧 **진행 중** — 실행 환경(MySQL 9.7 on Docker Compose) 구성 완료

백엔드 프레임워크 없이, 도메인 테이블을 직접 설계하고(PK/FK/제약조건) 데이터를 넣고
요구사항을 SQL 로 푸는 전 과정. 결과물은 **SQL 파일 3개 + 실행 결과**다.

- 과제 원문: 로컬 `../14-sql-domain-database.md`

## 선택 사항

| 항목 | 값 | 비고 |
|---|---|---|
| DB | **MySQL 9.7** | 공식 이미지 `mysql:9.7` (Docker Hub `lts` 태그). Docker Compose 로 띄운다 |
| 도메인 주제 | **가계부** | 회원 · 계좌 · 카테고리 · 거래 내역 · 월 예산 |
| 접속 도구 | **CLI** (컨테이너 안 `mysql`) | 로컬에 MySQL 클라이언트를 설치할 필요가 없다. DBeaver 등으로는 `127.0.0.1:3306` 접속 |
| ERD | **Mermaid** | `docs/erd.md` (GitHub 에서 바로 렌더) → `./run.sh erd` 로 PNG |

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
├── results/             # 제출물 4 — 실행 결과 텍스트 (./run.sh test --save)
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
- MySQL 은 InnoDB 가 FK 를 항상 검사하므로 별도 설정 없이 "없는 값 참조" 가 막힌다 (`check` 가 `foreign_key_checks` 도 확인).
- 포트를 바꾸려면 `.env` 의 `MYSQL_PORT` 를 고친다.

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
