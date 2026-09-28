-- =====================================================================
-- 미션 14 — 가계부 핵심 쿼리 16개 (MySQL 9.7)
-- 실행: ./run.sh test   (매번 DB 를 새로 만든 뒤 위에서부터 차례로 실행)
--
--   기본 조회 4  Q01 ~ Q04      집계     3  Q09 ~ Q11      인덱스    1  Q14
--   조인     4  Q05 ~ Q08      서브쿼리 2  Q12 ~ Q13      수정·삭제 2  Q15 ~ Q16
--
-- 과제 최소 합은 15개(4+4+3+1+2+1)다. 서브쿼리를 스칼라(Q12)·파생 테이블(Q13) 두 형태로 보이려고 하나 더 써서 16개다.
--
-- 날짜 조건은 CURDATE() 대신 날짜 리터럴로 고정했다 — 언제 실행해도 results/ 와 같은 결과가 나와야 한다.
-- 수정·삭제(Q15·Q16)는 앞 쿼리들의 결과를 바꾸지 않도록 맨 끝에 둔다.
-- MySQL 전용 문법을 쓴 쿼리에는 설명 아래 줄에 '[MySQL 전용]' 으로 표기했다.
-- =====================================================================


-- [Q01] 기본 조회 — 2026년 9월 거래 중 5만 원 이상인 것, 금액이 큰 순서로 5건
--       [MySQL 전용] LIMIT (표준 SQL 은 FETCH FIRST 5 ROWS ONLY)
SELECT id, entry_date, amount, memo
FROM ledger_entry
WHERE entry_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND amount >= 50000
ORDER BY amount DESC
LIMIT 5;

-- [Q02] 기본 조회 — 메모에 '커피'가 들어간 거래를 최근 순으로 검색
--       [MySQL 전용] LIMIT
SELECT id, entry_date, amount, memo
FROM ledger_entry
WHERE memo LIKE '%커피%'
ORDER BY entry_date DESC, id DESC
LIMIT 10;

-- [Q03] 기본 조회 — 2026년 5월 이후 가입한 회원 중 가장 최근 가입자 3명
--       [MySQL 전용] LIMIT
SELECT id, name, email, joined_at
FROM member
WHERE joined_at >= '2026-05-01'
ORDER BY joined_at DESC
LIMIT 3;

-- [Q04] 기본 조회 — 김민준의 생활비카드(계좌 2번) 최근 거래 5건
--       [MySQL 전용] LIMIT
SELECT id, entry_date, category_id, amount, memo
FROM ledger_entry
WHERE account_id = 2
ORDER BY entry_date DESC, id DESC
LIMIT 5;


-- [Q05] 조인(INNER) — 9월 1~10일 거래를 회원·계좌·카테고리 이름과 함께 보기
SELECT e.entry_date,
       m.name  AS member_name,
       a.name  AS account_name,
       c.name  AS category_name,
       c.entry_type,
       e.amount,
       e.memo
FROM ledger_entry e
INNER JOIN account  a ON a.id = e.account_id
INNER JOIN member   m ON m.id = a.member_id
INNER JOIN category c ON c.id = e.category_id
WHERE e.entry_date BETWEEN '2026-09-01' AND '2026-09-10'
ORDER BY e.entry_date, e.id;

-- [Q06] 조인(INNER) — 회원별 보유 계좌 목록
SELECT m.id   AS member_id,
       m.name AS member_name,
       a.name AS account_name,
       a.account_type,
       a.opened_at
FROM member m
INNER JOIN account a ON a.member_id = m.id
ORDER BY m.id, a.id;

-- [Q07] 조인(LEFT) — 계좌를 하나도 등록하지 않은 회원 찾기
SELECT m.id, m.name, m.joined_at
FROM member m
LEFT JOIN account a ON a.member_id = m.id
WHERE a.id IS NULL
ORDER BY m.id;

-- [Q08] 조인(LEFT) — 모든 카테고리의 9월 거래 건수와 합계 (거래가 없으면 0)
SELECT c.name       AS category_name,
       c.entry_type,
       COUNT(e.id)  AS entry_count,
       COALESCE(SUM(e.amount), 0) AS total_amount
FROM category c
LEFT JOIN ledger_entry e
       ON e.category_id = c.id
      AND e.entry_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY c.id, c.name, c.entry_type
ORDER BY total_amount DESC, c.id;


-- [Q09] 집계 — 월별 수입·지출 합계와 잔액
--       [MySQL 전용] DATE_FORMAT (표준 SQL 이라면 EXTRACT(YEAR/MONTH FROM ...) 두 개로 묶는다)
SELECT DATE_FORMAT(e.entry_date, '%Y-%m') AS month,
       SUM(CASE WHEN c.entry_type = 'INCOME'  THEN e.amount ELSE 0 END) AS income,
       SUM(CASE WHEN c.entry_type = 'EXPENSE' THEN e.amount ELSE 0 END) AS expense,
       SUM(CASE WHEN c.entry_type = 'INCOME'  THEN e.amount ELSE -e.amount END) AS balance
FROM ledger_entry e
INNER JOIN category c ON c.id = e.category_id
GROUP BY DATE_FORMAT(e.entry_date, '%Y-%m')
ORDER BY month;

-- [Q10] 집계 — 9월 지출 카테고리별 건수·합계·평균, 합계가 큰 순서 (지출 랭킹)
SELECT c.name               AS category_name,
       COUNT(*)             AS entry_count,
       SUM(e.amount)        AS total_amount,
       ROUND(AVG(e.amount)) AS avg_amount
FROM ledger_entry e
INNER JOIN category c ON c.id = e.category_id
WHERE c.entry_type = 'EXPENSE'
  AND e.entry_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY c.id, c.name
ORDER BY total_amount DESC, c.id;   -- 합계가 같으면 카테고리 id 순 (적지 않은 순서는 보장되지 않는다)

-- [Q11] 집계 — 7~9월 지출 합계가 10만 원 이상인 회원, 지출이 큰 순서
--       처리 순서: FROM·JOIN 으로 회원-계좌-거래-카테고리를 잇고 → WHERE 로 지출 거래만 남기고
--                 → GROUP BY 로 회원별로 묶어 COUNT·SUM 을 계산 → HAVING 으로 합계 10만 원 이상인 묶음만
--                 → SELECT → ORDER BY. 집계 결과로 거르는 조건은 묶인 뒤라야 판단할 수 있어 WHERE 가 아니라 HAVING 에 둔다.
SELECT m.name        AS member_name,
       COUNT(*)      AS expense_count,
       SUM(e.amount) AS total_expense
FROM member m
INNER JOIN account      a ON a.member_id = m.id
INNER JOIN ledger_entry e ON e.account_id = a.id
INNER JOIN category     c ON c.id = e.category_id
WHERE c.entry_type = 'EXPENSE'
GROUP BY m.id, m.name
HAVING SUM(e.amount) >= 100000
ORDER BY total_expense DESC, m.id;


-- [Q12] 서브쿼리(스칼라) — 전체 지출 평균보다 큰 지출 거래
SELECT e.id, e.entry_date, c.name AS category_name, e.amount, e.memo
FROM ledger_entry e
INNER JOIN category c ON c.id = e.category_id
WHERE c.entry_type = 'EXPENSE'
  AND e.amount > (SELECT AVG(e2.amount)
                  FROM ledger_entry e2
                  INNER JOIN category c2 ON c2.id = e2.category_id
                  WHERE c2.entry_type = 'EXPENSE')
ORDER BY e.amount DESC, e.id;

-- [Q13] 서브쿼리(FROM 절 파생 테이블) — 9월 예산을 넘긴 회원·카테고리와 초과 금액
--       ① 파생 테이블 s: 9월 거래를 (회원, 카테고리)별로 묶어 실제 지출 합계를 만든다
--       ② budget 에 회원·카테고리 이름과 s 를 (회원, 카테고리) 기준으로 붙인다
--       ③ 9월 예산이면서 지출이 예산보다 큰 행만 남긴다
--       ④ 초과액이 큰 순서로 정렬한다 (같으면 회원·카테고리 id 순)
SELECT m.name              AS member_name,
       c.name              AS category_name,
       b.amount            AS budget_amount,
       s.spent             AS spent_amount,
       s.spent - b.amount  AS over_amount
FROM budget b
INNER JOIN member   m ON m.id = b.member_id
INNER JOIN category c ON c.id = b.category_id
INNER JOIN (
    SELECT a.member_id, e.category_id, SUM(e.amount) AS spent
    FROM ledger_entry e
    INNER JOIN account a ON a.id = e.account_id
    WHERE e.entry_date BETWEEN '2026-09-01' AND '2026-09-30'
    GROUP BY a.member_id, e.category_id
) s ON s.member_id = b.member_id AND s.category_id = b.category_id
WHERE b.budget_month = '2026-09-01'
  AND s.spent > b.amount
ORDER BY over_amount DESC, m.id, c.id;


-- [Q14] 인덱스 — 거래 날짜(entry_date)에 인덱스를 만들고, 전후 실행 계획을 비교
--       적용 이유: 월별·기간별 조회(Q01·Q05·Q08·Q10·Q13)가 모두 entry_date 범위로 거래를 거르는데,
--                 거래 내역은 계속 쌓이는 테이블이라 인덱스가 없으면 매번 전체를 훑는다.
--       비교 범위: 9월 전체(47행 중 21행)로 비교하면 인덱스를 만든 뒤에도 ALL 이 나온다 — 조건에 맞는 행이
--                 테이블의 큰 비율이면 옵티마이저가 전체 읽기를 더 싸다고 본다. 그래서 9/20~30(8행)으로 비교한다.
--       [MySQL 전용] EXPLAIN FORMAT=TRADITIONAL (9.x 기본값은 TREE 형식)

-- [Q14-전] 인덱스가 없을 때 — type=ALL (47행 전체를 읽고 거른다)
EXPLAIN FORMAT=TRADITIONAL
SELECT * FROM ledger_entry
WHERE entry_date BETWEEN '2026-09-20' AND '2026-09-30';

CREATE INDEX idx_ledger_entry_entry_date ON ledger_entry (entry_date);

-- [Q14-후] 인덱스를 만든 뒤 — type=range, key=idx_ledger_entry_entry_date (해당 범위만 읽는다)
EXPLAIN FORMAT=TRADITIONAL
SELECT * FROM ledger_entry
WHERE entry_date BETWEEN '2026-09-20' AND '2026-09-30';


-- [Q15] 수정 — '기타'로 분류된 거래 중 메모에 '택시'가 있는 것을 '교통'으로 재분류
UPDATE ledger_entry
SET category_id = (SELECT id FROM category WHERE name = '교통')
WHERE category_id = (SELECT id FROM category WHERE name = '기타')
  AND memo LIKE '%택시%';

-- [Q15-확인] 재분류 결과 — 택시 거래 2건은 '교통', 택시가 아닌 '기타' 1건은 그대로
SELECT e.id, e.memo, c.name AS category_name
FROM ledger_entry e
INNER JOIN category c ON c.id = e.category_id
WHERE e.id IN (23, 39, 47)
ORDER BY e.id;

-- [Q16] 삭제 — 같은 날 같은 금액으로 두 번 입력된 중복 거래(46번) 삭제
DELETE FROM ledger_entry
WHERE id = 46;

-- [Q16-확인] 삭제 결과 — 9월 26일 이서연 주거래통장의 장보기는 1건만 남는다
SELECT id, entry_date, amount, memo
FROM ledger_entry
WHERE account_id = 3
  AND entry_date = '2026-09-26'
ORDER BY id;
