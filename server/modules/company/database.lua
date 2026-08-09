-- Persistent schema owned by the Company/Supplies vertical.

CompanyDatabase = CompanyDatabase or {}

local DDL = {
[[CREATE TABLE IF NOT EXISTS `sf_companies` (
  `id` VARCHAR(36) NOT NULL, `name` VARCHAR(80) NOT NULL,
  `owner_identifier` VARCHAR(64) NOT NULL, `treasury_cents` BIGINT NOT NULL DEFAULT 0,
  `monthly_budget_cents` BIGINT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_company_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_company_roles` (
  `company_id` VARCHAR(36) NOT NULL, `role_key` VARCHAR(32) NOT NULL,
  `permissions` LONGTEXT NOT NULL, `transaction_limit_cents` BIGINT DEFAULT NULL,
  PRIMARY KEY (`company_id`,`role_key`), CONSTRAINT `fk_sf_roles_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_company_members` (
  `company_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(100) NOT NULL, `role_key` VARCHAR(32) NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'active',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`company_id`,`identifier`), UNIQUE KEY `uniq_sf_member_identifier` (`identifier`),
  CONSTRAINT `fk_sf_members_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supplier_stock` (
  `item_id` VARCHAR(64) NOT NULL, `tier` VARCHAR(16) NOT NULL, `quantity` INT NOT NULL,
  `capacity` INT NOT NULL, `restock_amount` INT NOT NULL, `restock_seconds` INT NOT NULL,
  `last_restock_at` BIGINT NOT NULL, PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_drafts` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `created_by` VARCHAR(64) NOT NULL,
  `status` VARCHAR(32) NOT NULL, `subtotal_cents` BIGINT NOT NULL, `fee_cents` BIGINT NOT NULL, `total_cents` BIGINT NOT NULL,
  `approved_by` VARCHAR(64) DEFAULT NULL, `expires_at` BIGINT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sf_drafts_company` (`company_id`,`status`),
  CONSTRAINT `fk_sf_drafts_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_draft_lines` (
  `draft_id` VARCHAR(36) NOT NULL, `item_id` VARCHAR(64) NOT NULL, `quantity` INT NOT NULL, `unit_price_cents` INT NOT NULL,
  PRIMARY KEY (`draft_id`,`item_id`), CONSTRAINT `fk_sf_draft_lines` FOREIGN KEY (`draft_id`) REFERENCES `sf_supply_drafts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_orders` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `draft_id` VARCHAR(36) NOT NULL,
  `receipt_id` VARCHAR(36) NOT NULL, `status` VARCHAR(24) NOT NULL, `subtotal_cents` BIGINT NOT NULL,
  `fee_cents` BIGINT NOT NULL, `total_cents` BIGINT NOT NULL, `created_by` VARCHAR(64) NOT NULL,
  `due_at` BIGINT NOT NULL, `delivered_at` BIGINT DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_order_draft` (`draft_id`), UNIQUE KEY `uniq_sf_order_receipt` (`receipt_id`),
  KEY `idx_sf_orders_due` (`status`,`due_at`), CONSTRAINT `fk_sf_orders_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_order_lines` (
  `order_id` VARCHAR(36) NOT NULL, `item_id` VARCHAR(64) NOT NULL, `quantity` INT NOT NULL, `unit_price_cents` INT NOT NULL,
  PRIMARY KEY (`order_id`,`item_id`), CONSTRAINT `fk_sf_order_lines` FOREIGN KEY (`order_id`) REFERENCES `sf_supply_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_deliveries` (
  `id` VARCHAR(36) NOT NULL, `order_id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL,
  `status` VARCHAR(24) NOT NULL, `due_at` BIGINT NOT NULL, `delivered_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_delivery_order` (`order_id`), KEY `idx_sf_deliveries_due` (`status`,`due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_receipts` (
  `id` VARCHAR(36) NOT NULL, `order_id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL,
  `total_cents` BIGINT NOT NULL, `status` VARCHAR(24) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_receipt_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_company_ledger` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `idempotency_key` VARCHAR(100) NOT NULL,
  `entry_type` VARCHAR(32) NOT NULL, `direction` VARCHAR(16) NOT NULL, `amount_cents` BIGINT NOT NULL,
  `balance_after_cents` BIGINT NOT NULL, `actor_identifier` VARCHAR(64) NOT NULL,
  `linked_kind` VARCHAR(32) DEFAULT NULL, `linked_id` VARCHAR(36) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_ledger_idempotency` (`idempotency_key`), KEY `idx_sf_ledger_company` (`company_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_warehouse_lots` (
  `company_id` VARCHAR(36) NOT NULL, `item_id` VARCHAR(64) NOT NULL, `quantity` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`company_id`,`item_id`), CONSTRAINT `fk_sf_lots_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_warehouse_tool_units` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `item_id` VARCHAR(64) NOT NULL,
  `durability` DECIMAL(8,4) NOT NULL, `status` VARCHAR(24) NOT NULL DEFAULT 'available',
  `issue_id` VARCHAR(36) DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sf_tool_units_available` (`company_id`,`item_id`,`status`,`durability`),
  UNIQUE KEY `uniq_sf_tool_unit_issue` (`issue_id`),
  CONSTRAINT `fk_sf_tool_units_company` FOREIGN KEY (`company_id`) REFERENCES `sf_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_material_issues` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `item_id` VARCHAR(64) NOT NULL, `issued_units` INT NOT NULL, `consumed_units` INT NOT NULL DEFAULT 0,
  `returned_units` INT NOT NULL DEFAULT 0, `uses_spent` INT NOT NULL DEFAULT 0, `durability` DECIMAL(8,4) DEFAULT NULL,
  `warehouse_unit_id` VARCHAR(36) DEFAULT NULL, `idempotency_key` VARCHAR(100) NOT NULL,
  `status` VARCHAR(24) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sf_issues_member` (`company_id`,`identifier`,`status`),
  UNIQUE KEY `uniq_sf_issue_operation` (`company_id`,`idempotency_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sf_supply_outbox` (
  `id` VARCHAR(36) NOT NULL, `company_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `idempotency_key` VARCHAR(100) NOT NULL,
  `status` VARCHAR(24) NOT NULL, `payload` LONGTEXT NOT NULL, `attempts` INT NOT NULL DEFAULT 0,
  `last_error` VARCHAR(255) DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sf_outbox_operation` (`company_id`,`kind`,`idempotency_key`),
  KEY `idx_sf_outbox_pending` (`company_id`,`identifier`,`status`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function CompanyDatabase.Init()
    for index, statement in ipairs(DDL) do
        local ok, err = pcall(function() MySQL.query.await(statement) end)
        if not ok then
            Logger.Warn(('Company schema statement %d failed: %s'):format(index, tostring(err)), 'company_db')
            return false
        end
    end
    return true
end
