-- sonar_farm - Database schema (install)
-- Idempotent DDL. Safe to run multiple times.
-- Can be imported manually or auto-created at boot when
-- Config.Database.AutoCreateSchema is true (see server/modules/database).
--
-- NOTE on `slot`: the UNIQUE key on (zone, slot) makes double occupancy
-- impossible at the storage level, not just in application logic. MySQL and
-- MariaDB allow repeated NULLs in a unique index, which is exactly what we want:
-- legacy free-planted crops and debug crops carry no slot and never collide.

CREATE TABLE IF NOT EXISTS `farming_crops` (
  `id`          VARCHAR(36)  NOT NULL,               -- server-generated UUID
  `crop_type`   VARCHAR(64)  NOT NULL,
  `owner`       VARCHAR(64)  DEFAULT NULL,           -- citizenid of the planter
  `zone`        VARCHAR(64)  DEFAULT NULL,           -- key from config/zones.lua
  `slot`        INT          DEFAULT NULL,           -- 1-based slot index in that zone
  `cell`        VARCHAR(32)  NOT NULL,               -- spatial-hash key "gx:gy"
  `pos_x`       DOUBLE       NOT NULL,
  `pos_y`       DOUBLE       NOT NULL,
  `pos_z`       DOUBLE       NOT NULL,
  `heading`     FLOAT        NOT NULL DEFAULT 0,
  `planted_at`  BIGINT       NOT NULL,               -- unix seconds
  `growth_time` INT          NOT NULL DEFAULT 0,     -- seconds to full growth
  `state`       VARCHAR(16)  NOT NULL DEFAULT 'planted',
  `data`        LONGTEXT     DEFAULT NULL,           -- JSON: water/health/quality/etc.
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_zone_slot` (`zone`, `slot`),
  KEY `idx_cell` (`cell`),
  KEY `idx_zone` (`zone`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
