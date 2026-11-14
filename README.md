# SupportSphere — Accessible Assistance and Task Coordination System

SupportSphere is a Java 25 + JavaFX + MySQL desktop application for coordinating everyday assistance between requesters and volunteers.

## Core workflow
Requester registration → request creation → OPEN → intelligent matching → volunteer acceptance → ASSIGNED → IN_PROGRESS → COMPLETED → requester feedback → volunteer rating update.

## Technical highlights
- Layered Controller → Service → DAO → MySQL architecture
- OOP inheritance for User/Requester/Volunteer/Admin
- Generics, collections, Comparator and Optional
- Java time API for scheduling
- Custom exceptions and validation
- PreparedStatement/ResultSet/JDBC transactions
- Row-level locking with `SELECT ... FOR UPDATE` for safe assignment concurrency
- SHA-256 password hashing
- JavaFX/FXML dashboards, forms, alerts and accessible visual hierarchy
- In-app notifications, request history and audit-ready schema

## Demo accounts
- Admin: `admin@supportsphere.com` / `admin123`
- Volunteer: `volunteer@supportsphere.com` / `volunteer123`
- Requester: `requester@supportsphere.com` / `requester123`

## First-time setup
1. Start MySQL 8.x.
2. Open MySQL Workbench and run `database/schema.sql` once. It creates a fresh `supportsphere` database and intentionally drops only SupportSphere tables.
3. If your local MySQL password is not `root`, update `src/main/resources/application.properties`.
4. Run `mvn clean javafx:run`.


## Run on Windows

1. Start MySQL Server / MySQL80.
2. Run `database/schema.sql` once for a fresh SupportSphere database.
3. Set the MySQL password in `src/main/resources/application.properties`.
4. From the folder containing `pom.xml`, run `mvn clean javafx:run`.

Do not rerun the schema after entering real data because the script intentionally recreates the tables.
