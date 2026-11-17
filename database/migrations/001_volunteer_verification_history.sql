
/*
  SupportSphere volunteer verification history migration.

  Preconditions:
  - The selected database must be supportsphere.
  - users.user_id and volunteer_profiles.volunteer_id must be signed INT.
  - Existing data is preserved. No existing table or row is dropped.
  - Incompatible existing columns or foreign keys cause the migration to stop.
  - Both foreign-key preflight checks run before the first schema change.

  Important:
  MySQL DDL statements may implicitly commit. Take a database backup before
  running this migration. This script has NOT been executed as part of this
  review.
*/

SET @supportsphere_caller_database = DATABASE();

DROP PROCEDURE IF EXISTS supportsphere._supportsphere_001_vvh_migration;

DELIMITER $$

CREATE PROCEDURE supportsphere._supportsphere_001_vvh_migration(
    IN p_caller_database VARCHAR(64)
)
BEGIN
    DECLARE db_name VARCHAR(64);

    DECLARE history_object_exists INT DEFAULT 0;
    DECLARE history_exists INT DEFAULT 0;

    DECLARE volunteer_profiles_exists INT DEFAULT 0;
    DECLARE users_exists INT DEFAULT 0;
    DECLARE volunteer_id_parent_exists INT DEFAULT 0;
    DECLARE user_id_parent_exists INT DEFAULT 0;

    DECLARE rejection_reason_exists INT DEFAULT 0;
    DECLARE bad_rejection_reason INT DEFAULT 0;

    DECLARE volunteer_id_exists INT DEFAULT 0;
    DECLARE new_status_exists INT DEFAULT 0;
    DECLARE created_at_exists INT DEFAULT 0;

    DECLARE new_status_valid INT DEFAULT 0;
    DECLARE created_at_valid INT DEFAULT 0;

    DECLARE history_rows BIGINT DEFAULT 0;

    DECLARE bad_volunteer_id INT DEFAULT 0;
    DECLARE bad_changed_by INT DEFAULT 0;
    DECLARE decision_id_valid INT DEFAULT 0;

    DECLARE bad_old_status INT DEFAULT 0;
    DECLARE bad_reason INT DEFAULT 0;
    DECLARE bad_admin_note INT DEFAULT 0;

    DECLARE fk_name VARCHAR(64);
    DECLARE fk_delete_rule VARCHAR(30);
    DECLARE fk_column_count INT DEFAULT 0;
    DECLARE fk_match_count INT DEFAULT 0;
    DECLARE fk_conflict_count INT DEFAULT 0;
    DECLARE fk_constraint_count INT DEFAULT 0;

    DECLARE admin_fk_name VARCHAR(64);
    DECLARE admin_fk_delete_rule VARCHAR(30);
    DECLARE admin_fk_column_count INT DEFAULT 0;
    DECLARE admin_fk_match_count INT DEFAULT 0;
    DECLARE admin_fk_conflict_count INT DEFAULT 0;
    DECLARE admin_fk_constraint_count INT DEFAULT 0;

    DECLARE index_exists INT DEFAULT 0;
    DECLARE index_column_count INT DEFAULT 0;
    DECLARE index_match_count INT DEFAULT 0;

    SET db_name = p_caller_database;

    /*
      1. Validate the selected database.
    */
    IF db_name IS NULL OR LOWER(db_name) <> 'supportsphere' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration requires the selected database to be supportsphere.';
    END IF;

    /*
      2. Validate the parent tables and their referenced columns.
    */
    SELECT COUNT(*)
    INTO volunteer_profiles_exists
    FROM information_schema.tables
    WHERE table_schema = db_name
      AND table_name = 'volunteer_profiles'
      AND table_type = 'BASE TABLE';

    IF volunteer_profiles_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: supportsphere.volunteer_profiles must exist as a base table.';
    END IF;

    SELECT COUNT(*)
    INTO users_exists
    FROM information_schema.tables
    WHERE table_schema = db_name
      AND table_name = 'users'
      AND table_type = 'BASE TABLE';

    IF users_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: supportsphere.users must exist as a base table.';
    END IF;

    SELECT COUNT(*)
    INTO volunteer_id_parent_exists
    FROM information_schema.columns
    WHERE table_schema = db_name
      AND table_name = 'volunteer_profiles'
      AND column_name = 'volunteer_id';

    IF volunteer_id_parent_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: volunteer_profiles.volunteer_id must exist.';
    END IF;

    SELECT COUNT(*)
    INTO bad_volunteer_id
    FROM information_schema.columns
    WHERE table_schema = db_name
      AND table_name = 'volunteer_profiles'
      AND column_name = 'volunteer_id'
      AND (
          data_type <> 'int'
          OR column_type LIKE '%unsigned%'
          OR is_nullable <> 'NO'
      );

    IF bad_volunteer_id > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: volunteer_profiles.volunteer_id must exist as a signed INT NOT NULL.';
    END IF;

    SELECT COUNT(*)
    INTO user_id_parent_exists
    FROM information_schema.columns
    WHERE table_schema = db_name
      AND table_name = 'users'
      AND column_name = 'user_id';

    IF user_id_parent_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: users.user_id must exist.';
    END IF;

    SELECT COUNT(*)
    INTO bad_changed_by
    FROM information_schema.columns
    WHERE table_schema = db_name
      AND table_name = 'users'
      AND column_name = 'user_id'
      AND (
          data_type <> 'int'
          OR column_type LIKE '%unsigned%'
          OR is_nullable <> 'NO'
      );

    IF bad_changed_by > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: users.user_id must exist as a signed INT NOT NULL.';
    END IF;

    /*
      3. Determine whether the history object exists.
         A view with the intended table name is not safe to migrate.
    */
    SELECT COUNT(*)
    INTO history_object_exists
    FROM information_schema.tables
    WHERE table_schema = db_name
      AND table_name = 'volunteer_verification_history';

    SELECT COUNT(*)
    INTO history_exists
    FROM information_schema.tables
    WHERE table_schema = db_name
      AND table_name = 'volunteer_verification_history'
      AND table_type = 'BASE TABLE';

    IF history_object_exists > 0 AND history_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: volunteer_verification_history exists but is not a base table.';
    END IF;

    /*
      4. Validate rejection_reason if it already exists.
         An incompatible existing column is never silently accepted.
    */
    SELECT COUNT(*)
    INTO rejection_reason_exists
    FROM information_schema.columns
    WHERE table_schema = db_name
      AND table_name = 'volunteer_profiles'
      AND column_name = 'rejection_reason';

    IF rejection_reason_exists = 1 THEN
        SELECT COUNT(*)
        INTO bad_rejection_reason
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_profiles'
          AND column_name = 'rejection_reason'
          AND (
              data_type <> 'varchar'
              OR character_maximum_length <> 500
              OR is_nullable <> 'YES'
          );

        IF bad_rejection_reason > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing volunteer_profiles.rejection_reason must be VARCHAR(500) NULL.';
        END IF;
    END IF;

    /*
      5. Validate the structure of an existing history table.
    */
    IF history_exists = 1 THEN

        /*
          volunteer_id is essential for associating history rows with
          volunteers. It cannot safely be added to an existing table
          containing potentially unrelated historical records.
        */
        SELECT COUNT(*)
        INTO volunteer_id_exists
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'volunteer_id';

        IF volunteer_id_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: volunteer_verification_history.volunteer_id is missing and cannot be recovered automatically.';
        END IF;

        SELECT COUNT(*)
        INTO bad_volunteer_id
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'volunteer_id'
          AND (
              data_type <> 'int'
              OR column_type LIKE '%unsigned%'
              OR is_nullable <> 'NO'
          );

        IF bad_volunteer_id > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing volunteer_verification_history.volunteer_id must be signed INT NOT NULL.';
        END IF;

        /*
          changed_by may be added when absent because it is nullable.
          If it already exists, its definition must be compatible.
        */
        SELECT COUNT(*)
        INTO bad_changed_by
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'changed_by'
          AND (
              data_type <> 'int'
              OR column_type LIKE '%unsigned%'
              OR is_nullable <> 'YES'
          );

        IF bad_changed_by > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing volunteer_verification_history.changed_by must be signed INT NULL.';
        END IF;

        /*
          decision_id must already be a valid primary key.
          The migration will not guess how to reconstruct existing IDs.
        */
        SELECT COUNT(*)
        INTO decision_id_valid
        FROM information_schema.columns c
        WHERE c.table_schema = db_name
          AND c.table_name = 'volunteer_verification_history'
          AND c.column_name = 'decision_id'
          AND c.data_type = 'int'
          AND c.column_type NOT LIKE '%unsigned%'
          AND c.is_nullable = 'NO'
          AND c.extra LIKE '%auto_increment%'
          AND (
              SELECT COUNT(*)
              FROM information_schema.statistics s
              WHERE s.table_schema = db_name
                AND s.table_name = 'volunteer_verification_history'
                AND s.index_name = 'PRIMARY'
          ) = 1
          AND (
              SELECT COUNT(*)
              FROM information_schema.statistics s
              WHERE s.table_schema = db_name
                AND s.table_name = 'volunteer_verification_history'
                AND s.index_name = 'PRIMARY'
                AND s.column_name = 'decision_id'
                AND s.seq_in_index = 1
          ) = 1;

        IF decision_id_valid = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing decision_id must be a signed INT AUTO_INCREMENT sole primary key.';
        END IF;

        /*
          Read the row count before deciding whether missing required
          history fields can safely be added.
        */
        SELECT COUNT(*)
        INTO history_rows
        FROM volunteer_verification_history;

        SELECT COUNT(*)
        INTO new_status_exists
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'new_status';

        SELECT COUNT(*)
        INTO created_at_exists
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'created_at';

        /*
          Validate new_status when present.
        */
        IF new_status_exists = 1 THEN
            SELECT COUNT(*)
            INTO new_status_valid
            FROM information_schema.columns
            WHERE table_schema = db_name
              AND table_name = 'volunteer_verification_history'
              AND column_name = 'new_status'
              AND data_type = 'varchar'
              AND character_maximum_length = 20
              AND is_nullable = 'NO';

            IF new_status_valid = 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT =
                    'Migration blocked: existing new_status must be VARCHAR(20) NOT NULL.';
            END IF;
        END IF;

        /*
          Validate created_at when present.
        */
        IF created_at_exists = 1 THEN
            SELECT COUNT(*)
            INTO created_at_valid
            FROM information_schema.columns
            WHERE table_schema = db_name
              AND table_name = 'volunteer_verification_history'
              AND column_name = 'created_at'
              AND data_type = 'timestamp'
              AND datetime_precision = 0
              AND column_default IS NOT NULL
              AND UPPER(REPLACE(column_default, '()', '')) =
                  'CURRENT_TIMESTAMP';

            IF created_at_valid = 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT =
                    'Migration blocked: existing created_at must be TIMESTAMP DEFAULT CURRENT_TIMESTAMP.';
            END IF;
        END IF;

        /*
          Missing new_status or created_at cannot be populated safely
          when historical rows already exist.
        */
        IF history_rows > 0
           AND (new_status_exists = 0 OR created_at_exists = 0) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing history rows require manual definitions for missing new_status or created_at columns.';
        END IF;

        /*
          Validate old_status when present.
        */
        SELECT COUNT(*)
        INTO bad_old_status
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'old_status'
          AND (
              data_type <> 'varchar'
              OR character_maximum_length <> 20
              OR is_nullable <> 'YES'
          );

        IF bad_old_status > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing old_status must be VARCHAR(20) NULL.';
        END IF;

        /*
          Validate reason when present.
        */
        SELECT COUNT(*)
        INTO bad_reason
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'reason'
          AND (
              data_type <> 'varchar'
              OR character_maximum_length <> 500
              OR is_nullable <> 'YES'
          );

        IF bad_reason > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing reason must be VARCHAR(500) NULL.';
        END IF;

        /*
          Validate admin_note when present.
        */
        SELECT COUNT(*)
        INTO bad_admin_note
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'admin_note'
          AND (
              data_type <> 'varchar'
              OR character_maximum_length <> 500
              OR is_nullable <> 'YES'
          );

        IF bad_admin_note > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing admin_note must be VARCHAR(500) NULL.';
        END IF;

    END IF;

    /*
      6. Foreign-key preflight for volunteer_id.

      IMPORTANT:
      Aggregate ALL columns belonging to each FK constraint.
      Filtering to volunteer_id before grouping would hide the other
      columns of a composite foreign key.

      More than one FK involving volunteer_id is also rejected.
    */
    SELECT COUNT(*)
    INTO fk_constraint_count
    FROM (
        SELECT kcu.constraint_name
        FROM information_schema.key_column_usage kcu
        WHERE kcu.table_schema = db_name
          AND kcu.table_name = 'volunteer_verification_history'
          AND kcu.referenced_table_name IS NOT NULL
        GROUP BY kcu.constraint_name
        HAVING SUM(kcu.column_name = 'volunteer_id') > 0
    ) existing_volunteer_fks;

    IF fk_constraint_count > 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: multiple foreign keys involve volunteer_id. Manual review is required.';
    END IF;

    SELECT COUNT(*)
    INTO fk_conflict_count
    FROM (
        SELECT kcu.constraint_name
        FROM information_schema.key_column_usage kcu
        WHERE kcu.table_schema = db_name
          AND kcu.table_name = 'volunteer_verification_history'
          AND kcu.referenced_table_name IS NOT NULL
        GROUP BY kcu.constraint_name
        HAVING SUM(kcu.column_name = 'volunteer_id') > 0
           AND (
               COUNT(*) <> 1
               OR SUM(
                   kcu.column_name = 'volunteer_id'
                   AND kcu.referenced_table_schema = db_name
                   AND kcu.referenced_table_name = 'volunteer_profiles'
                   AND kcu.referenced_column_name = 'volunteer_id'
               ) <> 1
           )
    ) conflicting_volunteer_fks;

    IF fk_conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: every foreign key involving volunteer_id must be a single-column reference to supportsphere.volunteer_profiles.volunteer_id.';
    END IF;

    /*
      7. Foreign-key preflight for changed_by.

      The same all-columns aggregation is used here so composite
      constraints cannot pass unnoticed.
    */
    SELECT COUNT(*)
    INTO admin_fk_constraint_count
    FROM (
        SELECT kcu.constraint_name
        FROM information_schema.key_column_usage kcu
        WHERE kcu.table_schema = db_name
          AND kcu.table_name = 'volunteer_verification_history'
          AND kcu.referenced_table_name IS NOT NULL
        GROUP BY kcu.constraint_name
        HAVING SUM(kcu.column_name = 'changed_by') > 0
    ) existing_admin_fks;

    IF admin_fk_constraint_count > 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: multiple foreign keys involve changed_by. Manual review is required.';
    END IF;

    SELECT COUNT(*)
    INTO admin_fk_conflict_count
    FROM (
        SELECT kcu.constraint_name
        FROM information_schema.key_column_usage kcu
        WHERE kcu.table_schema = db_name
          AND kcu.table_name = 'volunteer_verification_history'
          AND kcu.referenced_table_name IS NOT NULL
        GROUP BY kcu.constraint_name
        HAVING SUM(kcu.column_name = 'changed_by') > 0
           AND (
               COUNT(*) <> 1
               OR SUM(
                   kcu.column_name = 'changed_by'
                   AND kcu.referenced_table_schema = db_name
                   AND kcu.referenced_table_name = 'users'
                   AND kcu.referenced_column_name = 'user_id'
               ) <> 1
           )
    ) conflicting_admin_fks;

    IF admin_fk_conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Migration blocked: every foreign key involving changed_by must be a single-column reference to supportsphere.users.user_id.';
    END IF;

    /*
      8. Validate existing indexes with the names this migration uses.
         An existing index with the expected name but wrong columns is
         not silently treated as a valid index.
    */
    SELECT COUNT(*)
    INTO index_exists
    FROM information_schema.statistics
    WHERE table_schema = db_name
      AND table_name = 'volunteer_verification_history'
      AND index_name = 'idx_vvh_volunteer_id';

    IF index_exists > 0 THEN
        SELECT COUNT(*)
        INTO index_column_count
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_volunteer_id';

        SELECT COUNT(*)
        INTO index_match_count
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_volunteer_id'
          AND column_name = 'volunteer_id'
          AND seq_in_index = 1;

        IF index_column_count <> 1 OR index_match_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing idx_vvh_volunteer_id is not a single-column index on volunteer_id.';
        END IF;
    END IF;

    SELECT COUNT(*)
    INTO index_exists
    FROM information_schema.statistics
    WHERE table_schema = db_name
      AND table_name = 'volunteer_verification_history'
      AND index_name = 'idx_vvh_created_at';

    IF index_exists > 0 THEN
        SELECT COUNT(*)
        INTO index_column_count
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_created_at';

        SELECT COUNT(*)
        INTO index_match_count
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_created_at'
          AND column_name = 'created_at'
          AND seq_in_index = 1;

        IF index_column_count <> 1 OR index_match_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: existing idx_vvh_created_at is not a single-column index on created_at.';
        END IF;
    END IF;

    /*
      ================================================================
      NO SCHEMA-CHANGING STATEMENT OCCURS ABOVE THIS POINT.
      ================================================================
    */

    /*
      9. Add rejection_reason only when it is absent.
    */
    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_profiles ADD COLUMN rejection_reason VARCHAR(500) NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_profiles'
          AND column_name = 'rejection_reason'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    /*
      10. Create the history table if it does not already exist.
    */
    CREATE TABLE IF NOT EXISTS volunteer_verification_history (
        decision_id INT PRIMARY KEY AUTO_INCREMENT,
        volunteer_id INT NOT NULL,
        old_status VARCHAR(20) NULL,
        new_status VARCHAR(20) NOT NULL,
        reason VARCHAR(500) NULL,
        changed_by INT NULL,
        admin_note VARCHAR(500) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT fk_vvh_volunteer
            FOREIGN KEY (volunteer_id)
            REFERENCES volunteer_profiles(volunteer_id)
            ON DELETE RESTRICT,

        CONSTRAINT fk_vvh_changed_by
            FOREIGN KEY (changed_by)
            REFERENCES users(user_id)
            ON DELETE SET NULL
    );

    /*
      11. Add missing non-key columns.

      The preflight checks above ensure that any existing versions of
      these columns already have the intended definitions.
    */

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN old_status VARCHAR(20) NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'old_status'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN new_status VARCHAR(20) NOT NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'new_status'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN reason VARCHAR(500) NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'reason'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN changed_by INT NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'changed_by'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN admin_note VARCHAR(500) NULL',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'admin_note'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
            'SELECT 1'
        )
        FROM information_schema.columns
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND column_name = 'created_at'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    /*
      12. Ensure the volunteer_id foreign key has ON DELETE RESTRICT.

      A correct existing FK is preserved. A wrong delete rule is replaced
      only after the preflight has established that its target and shape
      are safe to handle.
    */
    SET fk_name = NULL;
    SET fk_delete_rule = NULL;

    SELECT kcu.constraint_name, rc.delete_rule
    INTO fk_name, fk_delete_rule
    FROM information_schema.key_column_usage kcu
    JOIN information_schema.referential_constraints rc
      ON rc.constraint_schema = kcu.constraint_schema
     AND rc.table_name = kcu.table_name
     AND rc.constraint_name = kcu.constraint_name
    WHERE kcu.table_schema = db_name
      AND kcu.table_name = 'volunteer_verification_history'
      AND kcu.column_name = 'volunteer_id'
      AND kcu.referenced_table_schema = db_name
      AND kcu.referenced_table_name = 'volunteer_profiles'
      AND kcu.referenced_column_name = 'volunteer_id'
    LIMIT 1;

    IF fk_name IS NOT NULL THEN

        SELECT COUNT(*)
        INTO fk_column_count
        FROM information_schema.key_column_usage
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND constraint_name = fk_name;

        SELECT COUNT(*)
        INTO fk_match_count
        FROM information_schema.key_column_usage
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND constraint_name = fk_name
          AND column_name = 'volunteer_id'
          AND referenced_table_schema = db_name
          AND referenced_table_name = 'volunteer_profiles'
          AND referenced_column_name = 'volunteer_id';

        IF fk_column_count <> 1 OR fk_match_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: volunteer foreign key is composite or does not match the exact volunteer_id relationship.';
        END IF;

    END IF;

    SET @sql = IF(
        fk_name IS NOT NULL AND fk_delete_rule <> 'RESTRICT',
        CONCAT(
            'ALTER TABLE volunteer_verification_history DROP FOREIGN KEY `',
            REPLACE(fk_name, '`', '``'),
            '`'
        ),
        'SELECT 1'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = IF(
        fk_name IS NULL OR fk_delete_rule <> 'RESTRICT',
        'ALTER TABLE volunteer_verification_history ADD CONSTRAINT fk_vvh_volunteer FOREIGN KEY (volunteer_id) REFERENCES volunteer_profiles(volunteer_id) ON DELETE RESTRICT',
        'SELECT 1'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    /*
      13. Ensure changed_by references users.user_id with ON DELETE SET NULL.

      A correct existing FK is preserved.
    */
    SET admin_fk_name = NULL;
    SET admin_fk_delete_rule = NULL;

    SELECT kcu.constraint_name, rc.delete_rule
    INTO admin_fk_name, admin_fk_delete_rule
    FROM information_schema.key_column_usage kcu
    JOIN information_schema.referential_constraints rc
      ON rc.constraint_schema = kcu.constraint_schema
     AND rc.table_name = kcu.table_name
     AND rc.constraint_name = kcu.constraint_name
    WHERE kcu.table_schema = db_name
      AND kcu.table_name = 'volunteer_verification_history'
      AND kcu.column_name = 'changed_by'
      AND kcu.referenced_table_schema = db_name
      AND kcu.referenced_table_name = 'users'
      AND kcu.referenced_column_name = 'user_id'
    LIMIT 1;

    IF admin_fk_name IS NOT NULL THEN

        SELECT COUNT(*)
        INTO admin_fk_column_count
        FROM information_schema.key_column_usage
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND constraint_name = admin_fk_name;

        SELECT COUNT(*)
        INTO admin_fk_match_count
        FROM information_schema.key_column_usage
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND constraint_name = admin_fk_name
          AND column_name = 'changed_by'
          AND referenced_table_schema = db_name
          AND referenced_table_name = 'users'
          AND referenced_column_name = 'user_id';

        IF admin_fk_column_count <> 1 OR admin_fk_match_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                'Migration blocked: admin foreign key is composite or does not match the exact changed_by relationship.';
        END IF;

    END IF;

    SET @sql = IF(
        admin_fk_name IS NOT NULL
            AND admin_fk_delete_rule <> 'SET NULL',
        CONCAT(
            'ALTER TABLE volunteer_verification_history DROP FOREIGN KEY `',
            REPLACE(admin_fk_name, '`', '``'),
            '`'
        ),
        'SELECT 1'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = IF(
        admin_fk_name IS NULL
            OR admin_fk_delete_rule <> 'SET NULL',
        'ALTER TABLE volunteer_verification_history ADD CONSTRAINT fk_vvh_changed_by FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE SET NULL',
        'SELECT 1'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    /*
      14. Add the expected indexes when they are absent.
    */
    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD INDEX idx_vvh_volunteer_id (volunteer_id)',
            'SELECT 1'
        )
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_volunteer_id'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = (
        SELECT IF(
            COUNT(*) = 0,
            'ALTER TABLE volunteer_verification_history ADD INDEX idx_vvh_created_at (created_at)',
            'SELECT 1'
        )
        FROM information_schema.statistics
        WHERE table_schema = db_name
          AND table_name = 'volunteer_verification_history'
          AND index_name = 'idx_vvh_created_at'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END$$

DELIMITER ;

CALL supportsphere._supportsphere_001_vvh_migration(
    @supportsphere_caller_database
);

DROP PROCEDURE supportsphere._supportsphere_001_vvh_migration;
