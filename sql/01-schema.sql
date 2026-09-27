-- =====================================================================
-- 미션 14 — 가계부 도메인 스키마 (MySQL 9.7)
-- 실행: ./run.sh build   (DB 를 지우고 다시 만드는 일은 run.sh 가 맡는다)
--
-- 테이블 5개 · FK 5개 (모두 1:N)
--   member   1:N account         member   1:N budget
--   account  1:N ledger_entry    category 1:N budget
--   category 1:N ledger_entry
--
-- FK 가 가리킬 부모 테이블을 먼저 만든다: member → category → account → ledger_entry → budget
-- [MySQL 전용] AUTO_INCREMENT — 표준 SQL 의 GENERATED ... AS IDENTITY 를 MySQL 은 지원하지 않는다
-- =====================================================================

-- 회원
CREATE TABLE member (
    id          INT           NOT NULL AUTO_INCREMENT,
    email       VARCHAR(100)  NOT NULL,
    name        VARCHAR(50)   NOT NULL,
    joined_at   DATE          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_member_email UNIQUE (email)
);

-- 카테고리 — 수입/지출 구분은 카테고리가 가진다 (급여는 늘 수입, 식비는 늘 지출)
CREATE TABLE category (
    id          INT           NOT NULL AUTO_INCREMENT,
    name        VARCHAR(30)   NOT NULL,
    entry_type  VARCHAR(10)   NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_category_name UNIQUE (name),
    CONSTRAINT ck_category_entry_type CHECK (entry_type IN ('INCOME', 'EXPENSE'))
);

-- 계좌 — 은행 계좌·카드·현금 지갑처럼 돈이 드나드는 곳
CREATE TABLE account (
    id            INT           NOT NULL AUTO_INCREMENT,
    member_id     INT           NOT NULL,
    name          VARCHAR(50)   NOT NULL,
    account_type  VARCHAR(10)   NOT NULL,
    opened_at     DATE          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_account_member_name UNIQUE (member_id, name),   -- 같은 회원 안에서만 이름이 겹치면 안 된다
    CONSTRAINT ck_account_type CHECK (account_type IN ('BANK', 'CARD', 'CASH')),
    CONSTRAINT fk_account_member FOREIGN KEY (member_id) REFERENCES member (id)
);

-- 거래 내역 — 가계부의 한 줄
CREATE TABLE ledger_entry (
    id           INT           NOT NULL AUTO_INCREMENT,
    account_id   INT           NOT NULL,
    category_id  INT           NOT NULL,
    amount       INT           NOT NULL,   -- 원 단위, 항상 양수
    entry_date   DATE          NOT NULL,
    memo         VARCHAR(200),             -- 선택 입력
    PRIMARY KEY (id),
    CONSTRAINT ck_ledger_entry_amount CHECK (amount > 0),
    CONSTRAINT fk_ledger_entry_account  FOREIGN KEY (account_id)  REFERENCES account (id),
    CONSTRAINT fk_ledger_entry_category FOREIGN KEY (category_id) REFERENCES category (id)
);

-- 월 예산 — 회원이 카테고리별로 한 달에 쓰기로 한 금액
-- 지출 카테고리에만 걸어야 하지만, 다른 테이블 값을 봐야 하는 규칙이라 CHECK 로는 막을 수 없다
-- (트리거는 과제 범위 밖) — 입력하는 쪽이 지킨다.
CREATE TABLE budget (
    id            INT    NOT NULL AUTO_INCREMENT,
    member_id     INT    NOT NULL,
    category_id   INT    NOT NULL,
    budget_month  DATE   NOT NULL,   -- 그 달의 1일 (예: 2026-09-01)
    amount        INT    NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_budget_member_category_month UNIQUE (member_id, category_id, budget_month),
    CONSTRAINT ck_budget_month_first_day CHECK (EXTRACT(DAY FROM budget_month) = 1),
    CONSTRAINT ck_budget_amount CHECK (amount > 0),
    CONSTRAINT fk_budget_member   FOREIGN KEY (member_id)   REFERENCES member (id),
    CONSTRAINT fk_budget_category FOREIGN KEY (category_id) REFERENCES category (id)
);
