# Architecture

FXML UI → Controller → Service → DAO → JDBC/MySQL.

Controllers handle UI events; services contain business rules; DAOs own SQL; models carry domain state.
