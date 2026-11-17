package com.supportsphere.dao;

import com.supportsphere.util.DBConnection;
import java.sql.*;
import java.util.*;

public class AdminDAO {
    public void audit(int userId, String action, int entityId, String details) throws Exception {
        audit(userId, action, "VOLUNTEER", entityId, details);
    }

    public void audit(int userId, String action, String entityType, int entityId, String details) throws Exception {
        try (Connection c = DBConnection.getConnection();
             PreparedStatement p = c.prepareStatement("INSERT INTO audit_logs(user_id,action,entity_type,entity_id,details) VALUES(?,?,?,?,?)")) {
            p.setInt(1, userId); p.setString(2, action); p.setString(3, entityType);
            p.setInt(4, entityId); p.setString(5, details); p.executeUpdate();
        }
    }

    public Map<String, Integer> stats() throws Exception {
        Map<String, Integer> m = new LinkedHashMap<>();
        try (Connection c = DBConnection.getConnection()) {
            for (String[] x : new String[][]{
                    {"Total Users", "SELECT COUNT(*) FROM users"},
                    {"Active Volunteers", "SELECT COUNT(*) FROM users WHERE role='VOLUNTEER' AND status='ACTIVE'"},
                    {"Open Requests", "SELECT COUNT(*) FROM assistance_requests WHERE status='OPEN'"},
                    {"Active Assignments", "SELECT COUNT(*) FROM assignments WHERE status IN('ASSIGNED','IN_PROGRESS')"},
                    {"Completed Tasks", "SELECT COUNT(*) FROM assistance_requests WHERE status='COMPLETED'"}}) {
                try (Statement s = c.createStatement(); ResultSet r = s.executeQuery(x[1])) {
                    r.next(); m.put(x[0], r.getInt(1));
                }
            }
        }
        return m;
    }

    public List<Map<String, Object>> assignments() throws Exception {
        return list("SELECT a.assignment_id,a.request_id,ar.task_type,ru.name requester,vu.name volunteer,"
                + "a.status assignment_status,a.assigned_at,a.completed_at FROM assignments a "
                + "JOIN assistance_requests ar ON ar.request_id=a.request_id "
                + "JOIN users ru ON ru.user_id=ar.requester_id JOIN users vu ON vu.user_id=a.volunteer_id "
                + "ORDER BY a.assigned_at DESC");
    }

    public List<Map<String, Object>> feedback() throws Exception {
        return list("SELECT f.feedback_id,f.request_id,ru.name requester,vu.name volunteer,f.rating,f.comment,f.created_at "
                + "FROM feedback f JOIN users ru ON ru.user_id=f.requester_id JOIN users vu ON vu.user_id=f.volunteer_id "
                + "ORDER BY f.created_at DESC");
    }

    public List<Map<String, Object>> auditLogs() throws Exception {
        return list("SELECT a.audit_id,a.created_at,u.name actor,a.action,a.entity_id,a.details "
                + "FROM audit_logs a LEFT JOIN users u ON u.user_id=a.user_id ORDER BY a.created_at DESC");
    }

    private List<Map<String, Object>> list(String q) throws Exception {
        List<Map<String, Object>> rows = new ArrayList<>();
        try (Connection c = DBConnection.getConnection(); Statement s = c.createStatement(); ResultSet r = s.executeQuery(q)) {
            ResultSetMetaData md = r.getMetaData();
            while (r.next()) {
                Map<String, Object> row = new LinkedHashMap<>();
                for (int i = 1; i <= md.getColumnCount(); i++) row.put(md.getColumnLabel(i), r.getObject(i));
                rows.add(row);
            }
        }
        return rows;
    }
}
