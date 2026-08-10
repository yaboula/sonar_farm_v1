-- Persistent schema for Fields, Land, Work, Cargo and Buyer Orders.

FieldsDatabase = FieldsDatabase or {}

local DDL = {
[[CREATE TABLE IF NOT EXISTS `sf_fields` (
  `id` VARCHAR(64) NOT NULL, `legacy_zone` VARCHAR(64) DEFAULT NULL,
  `name` VARCHAR(100) NOT NULL, `location` VARCHAR(160) NOT NULL,
  `catalog_visible` TINYINT(1) NOT NULL DEFAULT 1, `starter_eligible` TINYINT(1) NOT NULL DEFAULT 0,
  `starter_priority` INT NOT NULL DEFAULT 999, `purchase_price_cents` BIGINT NOT NULL DEFAULT 0,
  `active_revision_id` VARCHAR(36) DEFAULT NULL, `state_sequence` BIGINT NOT NULL DEFAULT 0,
  `access_x` DOUBLE NOT NULL, `access_y` DOUBLE NOT NULL, `access_z` DOUBLE NOT NULL,
  `allowed_crops` LONGTEXT NOT NULL, `blip` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_field_legacy_zone` (`legacy_zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_revisions` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `revision_number` INT NOT NULL,
  `checksum` VARCHAR(64) NOT NULL, `status` VARCHAR(16) NOT NULL,
  `orientation` DOUBLE NOT NULL DEFAULT 0, `bounds_width` DOUBLE NOT NULL, `bounds_height` DOUBLE NOT NULL,
  `created_by` VARCHAR(64) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `activated_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_field_revision_number` (`field_id`,`revision_number`),
  UNIQUE KEY `uniq_sf_field_revision_checksum` (`field_id`,`checksum`),
  KEY `idx_sf_field_revision_status` (`field_id`,`status`),
  CONSTRAINT `fk_sf_field_revision_field` FOREIGN KEY (`field_id`) REFERENCES `sf_fields` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_rows` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `id` VARCHAR(96) NOT NULL,
  `label` VARCHAR(80) NOT NULL, `row_order` INT NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sf_field_row_order` (`revision_id`,`row_order`),
  CONSTRAINT `fk_sf_field_row_revision` FOREIGN KEY (`revision_id`) REFERENCES `sf_field_revisions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_slots` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `row_id` VARCHAR(96) NOT NULL,
  `id` VARCHAR(96) NOT NULL, `slot_order` INT NOT NULL, `legacy_index` INT NOT NULL,
  `pos_x` DOUBLE NOT NULL, `pos_y` DOUBLE NOT NULL, `pos_z` DOUBLE NOT NULL, `heading` DOUBLE NOT NULL,
  `normalized_x` DOUBLE NOT NULL, `normalized_y` DOUBLE NOT NULL, `cell_key` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sf_field_slot_legacy` (`revision_id`,`legacy_index`),
  KEY `idx_sf_field_slot_cell` (`cell_key`), KEY `idx_sf_field_slot_row` (`revision_id`,`row_id`,`slot_order`),
  CONSTRAINT `fk_sf_field_slot_revision` FOREIGN KEY (`revision_id`) REFERENCES `sf_field_revisions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_company_fields` (
  `field_id` VARCHAR(64) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `acquisition_kind` VARCHAR(16) NOT NULL,
  `price_cents` BIGINT NOT NULL DEFAULT 0, `acquired_by` VARCHAR(64) NOT NULL,
  `ledger_id` VARCHAR(36) DEFAULT NULL, `acquired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`field_id`), KEY `idx_sf_company_fields_company` (`company_id`,`acquired_at`),
  CONSTRAINT `fk_sf_company_field_field` FOREIGN KEY (`field_id`) REFERENCES `sf_fields` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_sf_company_field_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_purchase_drafts` (
  `field_id` VARCHAR(64) NOT NULL, `company_id` VARCHAR(36) NOT NULL,
  `prepared_by` VARCHAR(64) NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'prepared',
  `expires_at` BIGINT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`field_id`,`company_id`), KEY `idx_sf_field_purchase_company` (`company_id`,`status`,`expires_at`),
  CONSTRAINT `fk_sf_field_purchase_field` FOREIGN KEY (`field_id`) REFERENCES `sf_fields` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sf_field_purchase_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_crop_plans` (
  `id` VARCHAR(36) NOT NULL, `reference` VARCHAR(32) NOT NULL, `company_id` VARCHAR(36) NOT NULL,
  `field_id` VARCHAR(64) NOT NULL, `revision_id` VARCHAR(36) NOT NULL, `crop_type` VARCHAR(64) NOT NULL,
  `status` VARCHAR(24) NOT NULL, `created_by` VARCHAR(64) NOT NULL,
  `linked_work_id` VARCHAR(36) DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_crop_plan_reference` (`reference`),
  KEY `idx_sf_crop_plan_field_status` (`field_id`,`revision_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_crop_plan_rows` (
  `plan_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `revision_id` VARCHAR(36) NOT NULL,
  `row_id` VARCHAR(96) NOT NULL, `active_reservation` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`plan_id`,`row_id`), UNIQUE KEY `uniq_sf_active_plan_row` (`field_id`,`revision_id`,`row_id`,`active_reservation`),
  CONSTRAINT `fk_sf_crop_plan_row_plan` FOREIGN KEY (`plan_id`) REFERENCES `sf_crop_plans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_work` (
  `id` VARCHAR(36) NOT NULL, `reference` VARCHAR(32) NOT NULL, `kind` VARCHAR(16) NOT NULL,
  `company_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `revision_id` VARCHAR(36) NOT NULL,
  `plan_id` VARCHAR(36) DEFAULT NULL, `title` VARCHAR(120) NOT NULL, `objective` VARCHAR(255) NOT NULL,
  `status` VARCHAR(24) NOT NULL, `assignee_identifier` VARCHAR(64) DEFAULT NULL,
  `created_by` VARCHAR(64) NOT NULL, `reviewed_by` VARCHAR(64) DEFAULT NULL,
  `payout_cents` BIGINT NOT NULL DEFAULT 0, `escrow_status` VARCHAR(24) NOT NULL DEFAULT 'none',
  `deadline_at` BIGINT NOT NULL, `submitted_at` BIGINT DEFAULT NULL, `completed_at` BIGINT DEFAULT NULL,
  `review_note` VARCHAR(255) DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_work_reference` (`reference`),
  UNIQUE KEY `uniq_sf_work_plan` (`plan_id`),
  KEY `idx_sf_work_company_status` (`company_id`,`kind`,`status`),
  KEY `idx_sf_work_assignee` (`assignee_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_work_requirements` (
  `id` VARCHAR(36) NOT NULL, `work_id` VARCHAR(36) NOT NULL, `action` VARCHAR(24) NOT NULL,
  `row_ids` LONGTEXT NOT NULL, `crop_type` VARCHAR(64) DEFAULT NULL, `item_tier` VARCHAR(16) DEFAULT NULL,
  `target_count` INT NOT NULL, `current_count` INT NOT NULL DEFAULT 0,
  `threshold_key` VARCHAR(32) DEFAULT NULL, `threshold_value` DOUBLE DEFAULT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending', `requirement_order` INT NOT NULL,
  PRIMARY KEY (`id`), KEY `idx_sf_work_requirement` (`work_id`,`requirement_order`),
  CONSTRAINT `fk_sf_work_requirement_work` FOREIGN KEY (`work_id`) REFERENCES `sf_work` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_farming_operations` (
  `operation_id` VARCHAR(64) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `work_id` VARCHAR(36) DEFAULT NULL, `actor_identifier` VARCHAR(64) NOT NULL, `action` VARCHAR(24) NOT NULL,
  `crop_id` VARCHAR(36) DEFAULT NULL, `row_id` VARCHAR(96) DEFAULT NULL, `slot_id` VARCHAR(96) DEFAULT NULL,
  `payload` LONGTEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`operation_id`), KEY `idx_sf_operation_work` (`work_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_events` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL, `sequence` BIGINT NOT NULL,
  `event_type` VARCHAR(32) NOT NULL, `actor_identifier` VARCHAR(64) NOT NULL,
  `row_id` VARCHAR(96) DEFAULT NULL, `slot_id` VARCHAR(96) DEFAULT NULL, `payload` LONGTEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_field_event_sequence` (`field_id`,`sequence`),
  KEY `idx_sf_field_event_recent` (`field_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_company_cargo` (
  `id` VARCHAR(36) NOT NULL, `reference` VARCHAR(32) NOT NULL, `company_id` VARCHAR(36) NOT NULL,
  `field_id` VARCHAR(64) NOT NULL, `work_id` VARCHAR(36) DEFAULT NULL, `crop_id` VARCHAR(36) NOT NULL,
  `custodian_identifier` VARCHAR(64) NOT NULL, `item_id` VARCHAR(64) NOT NULL,
  `quantity` INT NOT NULL, `deposited_quantity` INT NOT NULL DEFAULT 0,
  `quality` DECIMAL(8,3) NOT NULL, `production` DECIMAL(8,3) NOT NULL, `quality_tier` VARCHAR(24) NOT NULL,
  `defect` VARCHAR(32) DEFAULT NULL, `status` VARCHAR(24) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_cargo_crop` (`crop_id`),
  KEY `idx_sf_cargo_custody` (`company_id`,`custodian_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_warehouse_produce_lots` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `item_id` VARCHAR(64) NOT NULL,
  `quality_tier` VARCHAR(24) NOT NULL, `quality` DECIMAL(8,3) NOT NULL, `production` DECIMAL(8,3) NOT NULL,
  `defect` VARCHAR(32) DEFAULT NULL, `quantity` INT NOT NULL, `reserved_quantity` INT NOT NULL DEFAULT 0,
  `source_cargo_id` VARCHAR(36) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_produce_cargo_lot` (`source_cargo_id`),
  KEY `idx_sf_produce_available` (`company_id`,`item_id`,`quality`,`quantity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_buyer_orders` (
  `id` VARCHAR(36) NOT NULL, `generation_key` VARCHAR(100) NOT NULL, `template_id` VARCHAR(64) NOT NULL,
  `company_id` VARCHAR(36) DEFAULT NULL, `buyer` VARCHAR(100) NOT NULL, `item_id` VARCHAR(64) NOT NULL,
  `quantity` INT NOT NULL, `minimum_quality` DECIMAL(8,3) NOT NULL, `payout_cents` BIGINT NOT NULL,
  `destination` LONGTEXT NOT NULL, `status` VARCHAR(24) NOT NULL, `deadline_at` BIGINT NOT NULL,
  `accepted_by` VARCHAR(64) DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_buyer_generation` (`generation_key`),
  KEY `idx_sf_buyer_orders_status` (`status`,`deadline_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_produce_reservations` (
  `id` VARCHAR(36) NOT NULL, `order_id` VARCHAR(36) NOT NULL, `lot_id` VARCHAR(36) NOT NULL,
  `quantity` INT NOT NULL, `status` VARCHAR(24) NOT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_order_lot_reservation` (`order_id`,`lot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_field_outbox` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `idempotency_key` VARCHAR(100) NOT NULL, `status` VARCHAR(32) NOT NULL,
  `payload` LONGTEXT NOT NULL, `attempts` INT NOT NULL DEFAULT 0, `last_error` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_field_outbox_operation` (`company_id`,`kind`,`idempotency_key`),
  KEY `idx_sf_field_outbox_pending` (`status`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function FieldsDatabase.Init()
    for index, statement in ipairs(DDL) do
        local ok, err = pcall(function() MySQL.query.await(statement) end)
        if not ok then
            Logger.Warn(('Fields schema statement %d failed: %s'):format(index, tostring(err)), 'fields_db')
            return false
        end
    end
    local hasWorkPlanKey = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.statistics
        WHERE table_schema=DATABASE() AND table_name='sf_work' AND index_name='uniq_sf_work_plan']])) or 0
    if hasWorkPlanKey == 0 then
        local ok, err = pcall(function() MySQL.query.await('ALTER TABLE sf_work ADD UNIQUE KEY uniq_sf_work_plan (plan_id)') end)
        if not ok then
            Logger.Warn(('Fields schema migration uniq_sf_work_plan failed: %s'):format(tostring(err)), 'fields_db')
            return false
        end
    end
    return true
end
