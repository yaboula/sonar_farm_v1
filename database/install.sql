-- sonar_farm - Database schema (install)
-- Idempotent DDL. Safe to run multiple times.
-- Can be imported manually or auto-created at boot when
-- Config.Database.AutoCreateSchema is true (see server/modules/database).

CREATE TABLE IF NOT EXISTS `farming_crops` (
  `id`          VARCHAR(36)  NOT NULL,               -- server-generated UUID
  `crop_type`   VARCHAR(64)  NOT NULL,
  `owner`       VARCHAR(64)  DEFAULT NULL,           -- citizenid of the planter
  `zone`        VARCHAR(64)  DEFAULT NULL,           -- key from config/zones.lua
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
  KEY `idx_cell` (`cell`),
  KEY `idx_zone` (`zone`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
