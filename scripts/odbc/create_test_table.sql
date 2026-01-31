-- Create table for CSV ingestion tests (database handled by script)
CREATE TABLE IF NOT EXISTS `login_domain` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `datahora` DATETIME NOT NULL,
  `usuario` VARCHAR(255) NOT NULL,
  `host` VARCHAR(255) NOT NULL,
  `ip` VARCHAR(45) NOT NULL,
  `serial` VARCHAR(255) NOT NULL,
  `linha_hash` BINARY(32) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_linha_hash` (`linha_hash`),
  KEY `idx_datahora` (`datahora`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
