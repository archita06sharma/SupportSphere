package com.supportsphere.controller;

import com.supportsphere.dao.*;
import com.supportsphere.model.*;
import com.supportsphere.service.*;
import com.supportsphere.util.*;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;
import java.util.*;

public class VolunteerDashboardController {
    @FXML Label welcome, rating, verification, skills, available, rejectionReason, assignedCount, activeCount, notificationCount;
    @FXML Button acceptButton, detailsButton, startButton, completeButton;
    @FXML TableView<AssistanceRequest> table;
    @FXML TableColumn<AssistanceRequest, String> idCol, taskCol, locationCol, urgencyCol, dateCol, matchCol;
    @FXML TableView<Map<String, Object>> tasksTable, historyTable;
    @FXML TableColumn<Map<String, Object>, String> myIdCol, myTaskCol, myStatusCol, myDateCol, myLocationCol;
    @FXML TableColumn<Map<String, Object>, String> historyIdCol, historyTaskCol, historyStatusCol, historyDateCol, historyLocationCol;
    @FXML TabPane taskTabs;

    private final RequestService requests = new RequestService();
    private final VolunteerDAO volunteers = new VolunteerDAO();
    private final MatchingService matching = new MatchingService();
    private final AssignmentService assignments = new AssignmentService();

    @FXML
    void initialize() {
        table.getSelectionModel().selectedItemProperty().addListener((o, oldValue, newValue) -> updateActionButtons());
        tasksTable.getSelectionModel().selectedItemProperty().addListener((o, oldValue, newValue) -> {
            if (newValue != null) historyTable.getSelectionModel().clearSelection();
            updateActionButtons();
        });
        historyTable.getSelectionModel().selectedItemProperty().addListener((o, oldValue, newValue) -> {
            if (newValue != null) tasksTable.getSelectionModel().clearSelection();
            updateActionButtons();
        });
        taskTabs.getSelectionModel().selectedItemProperty().addListener((o, oldValue, newValue) -> updateActionButtons());
        updateActionButtons();
        load();
    }

    private void updateActionButtons() {
        boolean recommended = taskTabs.getSelectionModel().getSelectedIndex() == 0;
        boolean active = taskTabs.getSelectionModel().getSelectedIndex() == 1;
        AssistanceRequest recommendedTask = table.getSelectionModel().getSelectedItem();
        Map<String, Object> activeTask = tasksTable.getSelectionModel().getSelectedItem();
        Map<String, Object> historyTask = historyTable.getSelectionModel().getSelectedItem();
        acceptButton.setDisable(!recommended || recommendedTask == null);
        detailsButton.setDisable(recommended ? recommendedTask == null : active ? activeTask == null : historyTask == null);
        String status = activeTask == null ? null : String.valueOf(activeTask.get("status"));
        startButton.setDisable(!active || !"ASSIGNED".equals(status));
        completeButton.setDisable(!active || !"IN_PROGRESS".equals(status));
    }

    private void load() {
        try {
            Volunteer volunteer = volunteers.findById(Session.getUser().getUserId())
                    .orElseThrow(() -> new IllegalStateException("Your volunteer profile is missing."));
            welcome.setText("Good day, " + volunteer.getName().split(" ")[0] + " 👋");
            rating.setText(String.format("%.1f ★ (%d)", volunteer.getRating(), volunteer.getRatingCount()));
            verification.setText(volunteer.getVerificationStatus());
            rejectionReason.setText(volunteer.getRejectionReason() == null || volunteer.getRejectionReason().isBlank()
                    ? "" : "Application note: " + volunteer.getRejectionReason());
            skills.setText(String.join(" · ", volunteer.getSkills()));
            available.setText(volunteer.getAvailabilityStart() + " – " + volunteer.getAvailabilityEnd());

            List<AssistanceRequest> shown = new ArrayList<>();
            for (AssistanceRequest request : requests.open()) {
                if (!matching.rank(request, List.of(volunteer)).isEmpty()) shown.add(request);
            }
            table.setItems(FXCollections.observableArrayList(shown));
            idCol.setCellValueFactory(c -> new SimpleStringProperty("#" + c.getValue().getRequestId()));
            taskCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().getTaskType()));
            locationCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().getLocationLabel()));
            urgencyCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().getUrgency().name()));
            dateCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().getPreferredDate() + " · " + c.getValue().getStartTime()));
            matchCol.setCellValueFactory(c -> {
                try {
                    var match = matching.rank(c.getValue(), List.of(volunteer));
                    return new SimpleStringProperty(match.isEmpty() ? "—" : match.getFirst().score() + "% match");
                } catch (Exception e) {
                    return new SimpleStringProperty("—");
                }
            });

            List<Map<String, Object>> mine = assignments.mine(volunteer.getUserId());
            List<Map<String, Object>> activeTasks = mine.stream()
                    .filter(x -> List.of("ASSIGNED", "IN_PROGRESS").contains(String.valueOf(x.get("status")))).toList();
            List<Map<String, Object>> historyTasks = mine.stream()
                    .filter(x -> List.of("COMPLETED", "CANCELLED").contains(String.valueOf(x.get("status")))).toList();
            tasksTable.setItems(FXCollections.observableArrayList(activeTasks));
            historyTable.setItems(FXCollections.observableArrayList(historyTasks));
            configureAssignmentColumns();
            assignedCount.setText("" + mine.stream().filter(x -> "ASSIGNED".equals(String.valueOf(x.get("status")))).count());
            activeCount.setText("" + activeTasks.size());
            notificationCount.setText("" + new NotificationDAO().count(volunteer.getUserId()));
            updateActionButtons();
        } catch (Exception e) {
            Dialogs.error("Dashboard error", e.getMessage());
        }
    }

    private void configureAssignmentColumns() {
        myIdCol.setCellValueFactory(c -> new SimpleStringProperty("#" + c.getValue().get("request_id")));
        myTaskCol.setCellValueFactory(c -> new SimpleStringProperty(String.valueOf(c.getValue().get("task_type"))));
        myStatusCol.setCellValueFactory(c -> new SimpleStringProperty(String.valueOf(c.getValue().get("status"))));
        myDateCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().get("preferred_date") + " · " + c.getValue().get("start_time")));
        myLocationCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().get("area") + " · " + c.getValue().get("city")));
        historyIdCol.setCellValueFactory(c -> new SimpleStringProperty("#" + c.getValue().get("request_id")));
        historyTaskCol.setCellValueFactory(c -> new SimpleStringProperty(String.valueOf(c.getValue().get("task_type"))));
        historyStatusCol.setCellValueFactory(c -> new SimpleStringProperty(String.valueOf(c.getValue().get("status"))));
        historyDateCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().get("preferred_date") + " · " + c.getValue().get("start_time")));
        historyLocationCol.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().get("area") + " · " + c.getValue().get("city")));
    }

    @FXML void accept() {
        AssistanceRequest request = table.getSelectionModel().getSelectedItem();
        if (request == null) {
            Dialogs.info("Select a task", "Choose a recommended request first.");
            return;
        }
        try {
            assignments.accept(request.getRequestId(), Session.getUser().getUserId());
            Dialogs.info("Request accepted", "You are now assigned to request #" + request.getRequestId() + ".");
            load();
        } catch (Exception e) {
            Dialogs.error("Could not accept request", e.getMessage());
            load();
        }
    }

    @FXML void details() {
        try {
            int id;
            String status;
            if (taskTabs.getSelectionModel().getSelectedIndex() == 0) {
                AssistanceRequest selected = table.getSelectionModel().getSelectedItem();
                if (selected == null) {
                    Dialogs.info("Select a task", "Choose a recommended task first.");
                    return;
                }
                id = selected.getRequestId();
                status = selected.getStatus().name();
            } else {
                Map<String, Object> selected = taskTabs.getSelectionModel().getSelectedIndex() == 1
                        ? tasksTable.getSelectionModel().getSelectedItem()
                        : historyTable.getSelectionModel().getSelectedItem();
                if (selected == null) {
                    Dialogs.info("Select a task", "Choose a task from the selected tab first.");
                    return;
                }
                id = ((Number) selected.get("request_id")).intValue();
                status = String.valueOf(selected.get("status"));
            }
            AssistanceRequest request = requests.get(id);
            String message = "Request ID: #" + id
                    + "\nDescription:\n" + request.getDescription()
                    + "\n\nLocation: " + request.getLocationLabel()
                    + "\nDate: " + request.getPreferredDate()
                    + "\nTime: " + request.getStartTime() + "–" + request.getEndTime()
                    + "\nUrgency: " + request.getUrgency()
                    + "\nStatus: " + status;
            Dialogs.info("Request details", message);
        } catch (Exception e) {
            Dialogs.error("Could not load details", e.getMessage());
        }
    }

    @FXML void start() { change("start"); }
    @FXML void complete() { change("complete"); }

    private void change(String action) {
        try {
            Map<String, Object> selected = tasksTable.getSelectionModel().getSelectedItem();
            if (selected == null) {
                Dialogs.info("Select a task", "Choose one of your active tasks first.");
                return;
            }
            String expected = action.equals("start") ? "ASSIGNED" : "IN_PROGRESS";
            if (!expected.equals(String.valueOf(selected.get("status")))) {
                Dialogs.info("Task cannot be updated", action.equals("start")
                        ? "Only assigned tasks can be started." : "Only in-progress tasks can be completed.");
                return;
            }
            int id = ((Number) selected.get("request_id")).intValue();
            if (action.equals("start")) assignments.start(id, Session.getUser().getUserId());
            else assignments.complete(id, Session.getUser().getUserId());
            Dialogs.info("Updated", "Request #" + id + " is now "
                    + (action.equals("start") ? "IN PROGRESS" : "COMPLETED") + ".");
            load();
        } catch (Exception e) {
            Dialogs.error("Could not update assignment", e.getMessage());
        }
    }

    @FXML void viewMyTasks() { load(); }

    @FXML void notifications() {
        try {
            NotificationDAO notification = new NotificationDAO();
            List<String> messages = notification.unread(Session.getUser().getUserId());
            Dialogs.info("Notifications", messages.isEmpty() ? "You're all caught up." : String.join("\n\n", messages));
            notification.markRead(Session.getUser().getUserId());
            load();
        } catch (Exception e) {
            Dialogs.error("Notifications error", e.getMessage());
        }
    }

    @FXML void logout() {
        Session.clear();
        try {
            SceneManager.show("login.fxml", "SupportSphere — Sign in");
        } catch (Exception ignored) {
        }
    }
}
