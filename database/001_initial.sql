-- PostgreSQL 15+; schema cho giai đoạn triển khai thực tế.
-- Dùng BIGINT VND (không dùng float); ngày giờ UTC/timestamptz; ngày nghiệp vụ Asia/Ho_Chi_Minh.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE roles (code text PRIMARY KEY CHECK(code IN ('admin','accountant','director','dispatcher','driver')),name text NOT NULL);
INSERT INTO roles VALUES ('admin','Quản trị'),('accountant','Kế toán'),('director','Giám đốc'),('dispatcher','Điều phối'),('driver','Tài xế');
CREATE TABLE drivers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), full_name text NOT NULL, phone varchar(20) NOT NULL UNIQUE,
 cccd_encrypted bytea, license_no_encrypted bytea, license_expiry date, address_encrypted bytea,
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz
);
CREATE TABLE users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), username varchar(120) NOT NULL UNIQUE,
 password_hash text NOT NULL, role_code text NOT NULL REFERENCES roles(code), driver_id uuid UNIQUE REFERENCES drivers(id),
 active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz,
 CONSTRAINT driver_role_link CHECK ((role_code='driver' AND driver_id IS NOT NULL) OR (role_code<>'driver' AND driver_id IS NULL))
);
CREATE TABLE vehicles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plate varchar(20) NOT NULL UNIQUE,
 type text NOT NULL CHECK(type IN ('car','motorbike')),brand text,model text,manufacture_year integer CHECK(manufacture_year BETWEEN 1950 AND 2100),
 seats smallint CHECK(seats BETWEEN 1 AND 80),registration_expiry date,insurance_expiry date,
 owner_name text,driver_id uuid REFERENCES drivers(id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'available' CHECK(status IN ('available','maintenance','inactive')),
 notes text,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz
);
CREATE TABLE routes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL,pickup text NOT NULL,dropoff text NOT NULL,
 estimated_fare_vnd bigint NOT NULL DEFAULT 0 CHECK(estimated_fare_vnd >= 0),active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz
);
CREATE TABLE bookings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code varchar(40) NOT NULL UNIQUE,
 route_id uuid REFERENCES routes(id) ON DELETE RESTRICT,driver_id uuid REFERENCES drivers(id) ON DELETE RESTRICT,
 vehicle_id uuid REFERENCES vehicles(id) ON DELETE RESTRICT,customer_name text NOT NULL,customer_phone varchar(20),
 pickup text NOT NULL,dropoff text NOT NULL,departure_at timestamptz NOT NULL,
 fare_vnd bigint NOT NULL DEFAULT 0 CHECK(fare_vnd>=0),notes text,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected','completed','cancelled')),
 created_by uuid REFERENCES users(id),reviewed_by uuid REFERENCES users(id),reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz
);
CREATE TABLE settlement_periods (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL UNIQUE,from_date date NOT NULL,to_date date NOT NULL,
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','locked','approved')),
 locked_by uuid REFERENCES users(id),locked_at timestamptz,approved_by uuid REFERENCES users(id),approved_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),CONSTRAINT valid_period CHECK(to_date>=from_date)
);
-- Snapshot theo kỳ: ghi nhận số liệu nguồn, không tính lại trực tiếp từ bảng xe/chuyến hiện tại.
CREATE TABLE settlements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),period_id uuid NOT NULL REFERENCES settlement_periods(id) ON DELETE RESTRICT,
 driver_id uuid NOT NULL REFERENCES drivers(id) ON DELETE RESTRICT,vehicle_id uuid REFERENCES vehicles(id) ON DELETE RESTRICT,
 gross_revenue_vnd bigint NOT NULL DEFAULT 0 CHECK(gross_revenue_vnd>=0),promo_vnd bigint NOT NULL DEFAULT 0 CHECK(promo_vnd>=0),
 card_rides_vnd bigint NOT NULL DEFAULT 0 CHECK(card_rides_vnd>=0),card_fee_vnd bigint NOT NULL DEFAULT 0 CHECK(card_fee_vnd>=0),
 tips_vnd bigint NOT NULL DEFAULT 0 CHECK(tips_vnd>=0),insured_trips integer NOT NULL DEFAULT 0 CHECK(insured_trips>=0),
 insurance_fee_vnd bigint NOT NULL DEFAULT 0 CHECK(insurance_fee_vnd>=0),app_fee_vnd bigint NOT NULL DEFAULT 0 CHECK(app_fee_vnd>=0),
 wallet_vnd bigint NOT NULL DEFAULT 0,wallet_return_vnd bigint NOT NULL DEFAULT 0,
 collection_status text NOT NULL DEFAULT 'pending' CHECK(collection_status IN ('pending','paid','none')),
 note text, source_import_id uuid, created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),deleted_at timestamptz,
 UNIQUE(period_id,driver_id)
);
CREATE TABLE ledger_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),doc_code text NOT NULL UNIQUE,
 driver_id uuid NOT NULL REFERENCES drivers(id) ON DELETE RESTRICT,
 settlement_id uuid REFERENCES settlements(id) ON DELETE RESTRICT,
 entry_type text NOT NULL CHECK(entry_type IN ('receivable','payment','adjustment','refund')),
 amount_vnd bigint NOT NULL CHECK(amount_vnd>0),note text,
 created_by uuid NOT NULL REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now(),
 reversed_at timestamptz,reversed_by uuid REFERENCES users(id),reversal_reason text
);
CREATE TABLE audit_logs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_id uuid REFERENCES users(id),action text NOT NULL,entity text NOT NULL,entity_id uuid,
 detail jsonb NOT NULL DEFAULT '{}'::jsonb,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE import_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),file_name text NOT NULL,sha256 text NOT NULL,
 status text NOT NULL DEFAULT 'processing' CHECK(status IN ('processing','completed','failed')),
 imported_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now(),completed_at timestamptz,
 UNIQUE(sha256)
);
CREATE TABLE import_rows (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE RESTRICT,
 row_number integer NOT NULL,source_data jsonb NOT NULL,validation_error text,
 UNIQUE(batch_id,row_number)
);
CREATE INDEX idx_bookings_departure ON bookings(departure_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_bookings_driver_date ON bookings(driver_id,departure_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_bookings_status ON bookings(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_settlements_period ON settlements(period_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_settlements_driver ON settlements(driver_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ledger_driver_time ON ledger_entries(driver_id,created_at DESC) WHERE reversed_at IS NULL;
CREATE INDEX idx_audit_time ON audit_logs(created_at DESC);
COMMIT;
