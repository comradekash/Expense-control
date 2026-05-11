
DROP VIEW vw_Budget_vs_Actual;
DROP VIEW vw_Monthly_Expense_Summary;

DROP TABLE Overspending_Log CASCADE CONSTRAINTS;
DROP TABLE Expenses CASCADE CONSTRAINTS;
DROP TABLE Budgets CASCADE CONSTRAINTS;
DROP TABLE Categories CASCADE CONSTRAINTS;
DROP TABLE Users CASCADE CONSTRAINTS;

DROP SEQUENCE seq_users;
DROP SEQUENCE seq_categories;
DROP SEQUENCE seq_budgets;
DROP SEQUENCE seq_expenses;
DROP SEQUENCE seq_log;

CREATE TABLE Users (
    user_id       NUMBER          PRIMARY KEY,
    full_name     VARCHAR2(100)   NOT NULL,
    email         VARCHAR2(150)   NOT NULL UNIQUE,
    phone         VARCHAR2(20),
    created_at    DATE            DEFAULT SYSDATE NOT NULL
);

CREATE TABLE Categories (
    category_id   NUMBER          PRIMARY KEY,
    category_name VARCHAR2(100)   NOT NULL UNIQUE,
    description   VARCHAR2(255)
);

CREATE TABLE Budgets (
    budget_id     NUMBER          PRIMARY KEY,
    user_id       NUMBER          NOT NULL,
    category_id   NUMBER          NOT NULL,
    month_year    VARCHAR2(7)     NOT NULL, -- Format: 'MM-YYYY'
    budget_limit  NUMBER(10,2)    NOT NULL CHECK (budget_limit > 0),
    CONSTRAINT fk_budget_user     FOREIGN KEY (user_id)     REFERENCES Users(user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_budget_category FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE CASCADE,
    CONSTRAINT uq_budget          UNIQUE (user_id, category_id, month_year)
);

CREATE TABLE Expenses (
    expense_id    NUMBER          PRIMARY KEY,
    user_id       NUMBER          NOT NULL,
    category_id   NUMBER          NOT NULL,
    amount        NUMBER(10,2)    NOT NULL CHECK (amount > 0),
    expense_date  DATE            DEFAULT SYSDATE NOT NULL,
    description   VARCHAR2(255),
    CONSTRAINT fk_expense_user     FOREIGN KEY (user_id)     REFERENCES Users(user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_expense_category FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE CASCADE
);

CREATE TABLE Overspending_Log (
    log_id        NUMBER          PRIMARY KEY,
    user_id       NUMBER          NOT NULL,
    category_id   NUMBER          NOT NULL,
    month_year    VARCHAR2(7)     NOT NULL,
    budget_limit  NUMBER(10,2),
    total_spent   NUMBER(10,2),
    excess_amount NUMBER(10,2),
    logged_at     DATE            DEFAULT SYSDATE NOT NULL
);

CREATE SEQUENCE seq_users START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_categories START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_budgets START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_expenses START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_log START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_users_id
BEFORE INSERT ON Users FOR EACH ROW
BEGIN
  IF :NEW.user_id IS NULL THEN
    SELECT seq_users.NEXTVAL INTO :NEW.user_id FROM dual;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_categories_id
BEFORE INSERT ON Categories FOR EACH ROW
BEGIN
  IF :NEW.category_id IS NULL THEN
    SELECT seq_categories.NEXTVAL INTO :NEW.category_id FROM dual;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_budgets_id
BEFORE INSERT ON Budgets FOR EACH ROW
BEGIN
  IF :NEW.budget_id IS NULL THEN
    SELECT seq_budgets.NEXTVAL INTO :NEW.budget_id FROM dual;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_expenses_id
BEFORE INSERT ON Expenses FOR EACH ROW
BEGIN
  IF :NEW.expense_id IS NULL THEN
    SELECT seq_expenses.NEXTVAL INTO :NEW.expense_id FROM dual;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_log_id
BEFORE INSERT ON Overspending_Log FOR EACH ROW
BEGIN
  IF :NEW.log_id IS NULL THEN
    SELECT seq_log.NEXTVAL INTO :NEW.log_id FROM dual;
  END IF;
END;
/

INSERT INTO Categories (category_name, description) VALUES ('Food', 'Groceries, dining out, snacks');
INSERT INTO Categories (category_name, description) VALUES ('Transport', 'Fuel, ride-hailing, public transit');
INSERT INTO Categories (category_name, description) VALUES ('Utilities', 'Electricity, gas, internet bills');
INSERT INTO Categories (category_name, description) VALUES ('Entertainment', 'Movies, subscriptions, events');
INSERT INTO Categories (category_name, description) VALUES ('Healthcare', 'Medicines, doctor visits');
INSERT INTO Categories (category_name, description) VALUES ('Education', 'Books, courses, tuition');

COMMIT;

CREATE OR REPLACE VIEW vw_Monthly_Expense_Summary AS
SELECT
    u.user_id,
    u.full_name,
    c.category_name,
    TO_CHAR(e.expense_date, 'MM-YYYY')   AS month_year,
    SUM(e.amount)                         AS total_spent
FROM
    Expenses  e
    JOIN Users      u ON e.user_id     = u.user_id
    JOIN Categories c ON e.category_id = c.category_id
GROUP BY
    u.user_id, u.full_name, c.category_name,
    TO_CHAR(e.expense_date, 'MM-YYYY');

CREATE OR REPLACE VIEW vw_Budget_vs_Actual AS
SELECT
    u.full_name,
    c.category_name,
    b.month_year,
    b.budget_limit,
    NVL(SUM(e.amount), 0)                                   AS total_spent,
    b.budget_limit - NVL(SUM(e.amount), 0)                  AS remaining_budget,
    ROUND(NVL(SUM(e.amount), 0) / b.budget_limit * 100, 2)  AS utilization_pct,
    CASE
        WHEN NVL(SUM(e.amount), 0) > b.budget_limit THEN 'OVER BUDGET'
        WHEN NVL(SUM(e.amount), 0) >= b.budget_limit * 0.9  THEN 'NEAR LIMIT'
        ELSE 'WITHIN BUDGET'
    END          AS budget_status
FROM
    Budgets b
    JOIN Users u ON b.user_id = u.user_id
    JOIN Categories c ON b.category_id = c.category_id
    LEFT JOIN Expenses e ON b.user_id = e.user_id 
                         AND b.category_id = e.category_id 
                         AND b.month_year = TO_CHAR(e.expense_date, 'MM-YYYY')
GROUP BY
    u.full_name, c.category_name, b.month_year, b.budget_limit;