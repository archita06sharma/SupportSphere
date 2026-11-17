package com.supportsphere.controller;

import com.supportsphere.dao.*;
import com.supportsphere.model.*;
import com.supportsphere.service.RequestService;
import com.supportsphere.util.*;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;
import java.util.*;

public class AdminDashboardController {
    @FXML Label users, volunteers, open, active, completed, volunteerEmpty;
    @FXML Button blockButton, unblockButton, usersViewProfileButton, viewProfileButton, verifyVolunteerButton, rejectVolunteerButton, reopenVolunteerButton;
    @FXML TextField volunteerSearch, auditSearch;
    @FXML ComboBox<String> volunteerStatusFilter, assignmentFilter, auditActionFilter;
    @FXML TableView<Map<String,Object>> requestsTable, usersTable, assignmentsTable, feedbackTable, auditTable;
    @FXML TableColumn<Map<String,Object>,String> userCol, roleCol, statusCol, reqCol, assignmentCol, assignmentRequestCol, assignmentTaskCol, assignmentRequesterCol, assignmentVolunteerCol, assignmentStatusCol, assignmentDateCol, assignmentCompletedCol, feedbackCol, feedbackRequestCol, feedbackRequesterCol, feedbackVolunteerCol, feedbackRatingCol, feedbackCommentCol, feedbackDateCol, auditCol, auditTimestampCol, auditActorCol, auditActionCol, auditEntityCol, auditDetailsCol;
    @FXML TableView<Volunteer> volunteersTable;
    @FXML TableColumn<Volunteer,String> volunteerIdCol, volunteerNameCol, volunteerEmailCol, volunteerStatusCol, volunteerRatingCol, volunteerExperienceCol, volunteerLocationCol;

    private final AdminDAO dao = new AdminDAO(); private final UserDAO usersDao = new UserDAO();
    private final VolunteerDAO volDao = new VolunteerDAO(); private final RequestService req = new RequestService();
    private List<Volunteer> volunteerRows = List.of(); private List<Map<String,Object>> assignmentRows = List.of(), auditRows = List.of();

    @FXML void initialize() {
        usersTable.getSelectionModel().selectedItemProperty().addListener((o,a,b)->updateUserActions());
        volunteersTable.getSelectionModel().selectedItemProperty().addListener((o,a,b)->updateVolunteerActions());
        volunteerSearch.textProperty().addListener((o,a,b)->filterVolunteers());
        auditSearch.textProperty().addListener((o,a,b)->filterAudit());
        volunteerStatusFilter.getItems().setAll("All","PENDING","VERIFIED","REJECTED"); volunteerStatusFilter.setValue("All");
        assignmentFilter.getItems().setAll("All","ASSIGNED","IN_PROGRESS","COMPLETED","CANCELLED"); assignmentFilter.setValue("All");
        auditActionFilter.getItems().setAll("All","USER_BLOCKED","USER_UNBLOCKED","VOLUNTEER_VERIFIED","VOLUNTEER_REJECTED","VOLUNTEER_APPLICATION_REOPENED"); auditActionFilter.setValue("All");
        volunteerStatusFilter.valueProperty().addListener((o,a,b)->filterVolunteers());
        assignmentFilter.valueProperty().addListener((o,a,b)->filterAssignments());
        auditActionFilter.valueProperty().addListener((o,a,b)->filterAudit());
        updateUserActions(); updateVolunteerActions(); load();
    }

    private void load() {
        try {
            Map<String,Integer> s=dao.stats(); users.setText(""+s.get("Total Users")); volunteers.setText(""+s.get("Active Volunteers"));
            open.setText(""+s.get("Open Requests")); active.setText(""+s.get("Active Assignments")); completed.setText(""+s.get("Completed Tasks"));
            loadUsers(); loadVolunteers(); loadRequests(); assignmentRows=dao.assignments(); filterAssignments(); loadFeedback(); auditRows=dao.auditLogs(); filterAudit();
        } catch(Exception e){ Dialogs.error("Admin dashboard error",e.getMessage()); }
    }
    private void loadUsers() throws Exception {
        var rows=FXCollections.<Map<String,Object>>observableArrayList();
        for(User u:usersDao.findAll()){Map<String,Object> r=new LinkedHashMap<>();r.put("id",u.getUserId());r.put("user",u.getName());r.put("role",u.getRole());r.put("status",u.getStatus());rows.add(r);}
        usersTable.setItems(rows); userCol.setCellValueFactory(c->text(c.getValue(),"user")); roleCol.setCellValueFactory(c->text(c.getValue(),"role")); statusCol.setCellValueFactory(c->text(c.getValue(),"status")); updateUserActions();
    }
    private void loadVolunteers() throws Exception { volunteerRows=volDao.findAll(); filterVolunteers(); }
    private void filterVolunteers(){if(volunteersTable==null)return;String q=volunteerSearch.getText().trim().toLowerCase(),f=volunteerStatusFilter.getValue();var rows=volunteerRows.stream().filter(v->"All".equals(f)||f.equals(v.getVerificationStatus())).filter(v->q.isBlank()||(""+v.getUserId()).contains(q)||v.getName().toLowerCase().contains(q)||v.getEmail().toLowerCase().contains(q)).toList();volunteersTable.setItems(FXCollections.observableArrayList(rows));volunteerEmpty.setVisible(rows.isEmpty());configureVolunteerColumns();updateVolunteerActions();}
    private void configureVolunteerColumns(){volunteerIdCol.setCellValueFactory(c->text(""+c.getValue().getUserId()));volunteerNameCol.setCellValueFactory(c->text(c.getValue().getName()));volunteerEmailCol.setCellValueFactory(c->text(c.getValue().getEmail()));volunteerStatusCol.setCellValueFactory(c->text(c.getValue().getVerificationStatus()));volunteerRatingCol.setCellValueFactory(c->text(String.format("%.1f (%d)",c.getValue().getRating(),c.getValue().getRatingCount())));volunteerExperienceCol.setCellValueFactory(c->text(c.getValue().getExperienceYears()+" years"));volunteerLocationCol.setCellValueFactory(c->text(c.getValue().getLocationLabel()));}
    private void loadRequests() throws Exception {var rows=FXCollections.<Map<String,Object>>observableArrayList();for(AssistanceRequest r:req.all()){Map<String,Object>x=new LinkedHashMap<>();x.put("request","#"+r.getRequestId()+" · "+r.getTaskType()+" · "+r.getStatus()+" · "+(r.getVolunteerName()==null?"—":r.getVolunteerName()));rows.add(x);}requestsTable.setItems(rows);reqCol.setCellValueFactory(c->text(c.getValue(),"request"));}
    private void loadFeedback() throws Exception {var rows=FXCollections.observableArrayList(dao.feedback());feedbackTable.setItems(rows);feedbackCol.setCellValueFactory(c->text(c.getValue(),"feedback_id"));feedbackRequestCol.setCellValueFactory(c->text(c.getValue(),"request_id"));feedbackRequesterCol.setCellValueFactory(c->text(c.getValue(),"requester"));feedbackVolunteerCol.setCellValueFactory(c->text(c.getValue(),"volunteer"));feedbackRatingCol.setCellValueFactory(c->text(c.getValue(),"rating"));feedbackCommentCol.setCellValueFactory(c->text(c.getValue(),"comment"));feedbackDateCol.setCellValueFactory(c->text(c.getValue(),"created_at"));}
    private void filterAssignments(){if(assignmentsTable==null)return;String f=assignmentFilter.getValue();var rows=assignmentRows.stream().filter(r->"All".equals(f)||f.equals(String.valueOf(r.get("assignment_status")))).toList();assignmentsTable.setItems(FXCollections.observableArrayList(rows));assignmentCol.setCellValueFactory(c->text(c.getValue(),"assignment_id"));assignmentRequestCol.setCellValueFactory(c->text(c.getValue(),"request_id"));assignmentTaskCol.setCellValueFactory(c->text(c.getValue(),"task_type"));assignmentRequesterCol.setCellValueFactory(c->text(c.getValue(),"requester"));assignmentVolunteerCol.setCellValueFactory(c->text(c.getValue(),"volunteer"));assignmentStatusCol.setCellValueFactory(c->text(c.getValue(),"assignment_status"));assignmentDateCol.setCellValueFactory(c->text(c.getValue(),"assigned_at"));assignmentCompletedCol.setCellValueFactory(c->text(c.getValue(),"completed_at"));}
    private void filterAudit(){if(auditTable==null)return;String q=auditSearch.getText().trim().toLowerCase(),f=auditActionFilter.getValue();var rows=auditRows.stream().filter(r->"All".equals(f)||f.equals(String.valueOf(r.get("action")))).filter(r->q.isBlank()||r.toString().toLowerCase().contains(q)).toList();auditTable.setItems(FXCollections.observableArrayList(rows));auditCol.setCellValueFactory(c->text(c.getValue(),"audit_id"));auditTimestampCol.setCellValueFactory(c->text(c.getValue(),"created_at"));auditActorCol.setCellValueFactory(c->text(c.getValue(),"actor"));auditActionCol.setCellValueFactory(c->text(c.getValue(),"action"));auditEntityCol.setCellValueFactory(c->text(c.getValue(),"entity_id"));auditDetailsCol.setCellValueFactory(c->text(c.getValue(),"details"));}
    private SimpleStringProperty text(Object value){return new SimpleStringProperty(String.valueOf(value==null?"—":value));}
    private SimpleStringProperty text(Map<String,Object> row,String key){return text(row.get(key));}
    private void updateUserActions(){Map<String,Object> r=usersTable.getSelectionModel().getSelectedItem();boolean selected=r!=null,self=selected&&((Number)r.get("id")).intValue()==Session.getUser().getUserId();boolean exactlyOne=usersTable.getSelectionModel().getSelectedItems().size()==1;usersViewProfileButton.setDisable(!exactlyOne);blockButton.setDisable(!selected||self||!"ACTIVE".equals(r.get("status")));unblockButton.setDisable(!selected||self||!"BLOCKED".equals(r.get("status")));}
    private void updateVolunteerActions(){Volunteer v=volunteersTable.getSelectionModel().getSelectedItem();boolean active=v!=null&&"ACTIVE".equals(v.getStatus());viewProfileButton.setDisable(v==null);verifyVolunteerButton.setDisable(!active||v==null||!"PENDING".equals(v.getVerificationStatus()));rejectVolunteerButton.setDisable(!active||v==null||!"PENDING".equals(v.getVerificationStatus()));reopenVolunteerButton.setDisable(!active||v==null||!"REJECTED".equals(v.getVerificationStatus()));}
    @FXML void viewProfile(){Volunteer v=volunteersTable.getSelectionModel().getSelectedItem();if(v==null){Dialogs.info("Select a volunteer","Choose a volunteer profile first.");return;}showVolunteerProfile(v);}
    @FXML void viewUserProfile(){List<Map<String,Object>> selected=usersTable.getSelectionModel().getSelectedItems();if(selected.size()!=1){Dialogs.info("Select one user","Choose exactly one user profile first.");return;}try{int id=((Number)selected.get(0).get("id")).intValue();User user=usersDao.findById(id).orElseThrow(()->new IllegalStateException("User profile not found."));if(user instanceof Volunteer){Volunteer volunteer=volDao.findById(id).orElseThrow(()->new IllegalStateException("Volunteer profile not found."));showVolunteerProfile(volunteer);return;}String requestSummary="";if(user instanceof Requester){List<AssistanceRequest> requests=req.mine(id);long openRequests=requests.stream().filter(r->r.getStatus()==RequestStatus.OPEN).count();long activeRequests=requests.stream().filter(r->r.getStatus()==RequestStatus.ASSIGNED||r.getStatus()==RequestStatus.IN_PROGRESS).count();long completedRequests=requests.stream().filter(r->r.getStatus()==RequestStatus.COMPLETED).count();requestSummary="\nRequests: "+requests.size()+" total, "+openRequests+" open, "+activeRequests+" active, "+completedRequests+" completed";}Dialogs.info("User profile","User ID: "+user.getUserId()+"\nName: "+user.getName()+"\nEmail: "+user.getEmail()+"\nPhone: "+user.getPhone()+"\nAccount status: "+user.getStatus()+"\nRole: "+user.getRole()+"\nLocation: "+user.getLocationLabel()+requestSummary);}catch(Exception e){Dialogs.error("Could not load user profile",e.getMessage());}}
    private void showVolunteerProfile(Volunteer v){Dialogs.info("Volunteer profile","Volunteer ID: "+v.getUserId()+"\nName: "+v.getName()+"\nEmail: "+v.getEmail()+"\nPhone: "+v.getPhone()+"\nAccount status: "+v.getStatus()+"\nVerification: "+v.getVerificationStatus()+"\nRejection reason: "+(v.getRejectionReason()==null?"—":v.getRejectionReason())+"\nRating: "+String.format("%.1f (%d reviews)",v.getRating(),v.getRatingCount())+"\nExperience: "+v.getExperienceYears()+" years\nLocation: "+v.getLocationLabel()+"\nSkills: "+(v.getSkills().isEmpty()?"None listed":String.join(", ",v.getSkills()))+"\nAvailability: "+v.getAvailabilityStart()+" – "+v.getAvailabilityEnd());}
    @FXML void verifyVolunteer(){updateVerification("VERIFIED","Verify volunteer","Verify this volunteer profile?","");}
    @FXML void rejectVolunteer(){String reason=Dialogs.text("Reject volunteer","Enter the rejection reason:");if(reason.isBlank()){Dialogs.info("Reason required","A rejection reason is required.");return;}updateVerification("REJECTED","Reject volunteer","Reject this volunteer profile?",reason);}
    @FXML void reopenVolunteer(){String note=Dialogs.text("Reopen volunteer","Enter an administrative note for reconsideration:");if(note.isBlank()){Dialogs.info("Note required","A note is required to reopen an application.");return;}updateVerification("PENDING","Reopen application","Return this application to PENDING?",note);}
    private void updateVerification(String status,String title,String question,String reason){Volunteer v=volunteersTable.getSelectionModel().getSelectedItem();if(v==null){Dialogs.info("Select a volunteer","Choose a volunteer profile first.");return;}if(!"ACTIVE".equals(v.getStatus())){Dialogs.info("Action unavailable","Blocked volunteer accounts cannot be changed.");return;}if(!Dialogs.confirm(title,question))return;try{volDao.updateVerification(v.getUserId(),status,reason,Session.getUser().getUserId());Dialogs.info("Volunteer updated","The verification decision was saved.");loadVolunteers();auditRows=dao.auditLogs();filterAudit();}catch(Exception e){Dialogs.error("Could not update volunteer",e.getMessage());}}
    @FXML void block(){updateStatus("BLOCKED","Block user","Are you sure you want to block this account?","User blocked");}
    @FXML void unblock(){updateStatus("ACTIVE","Unblock user","Restore access for this account?","User unblocked");}
    private void updateStatus(String status,String title,String question,String success){Map<String,Object> r=usersTable.getSelectionModel().getSelectedItem();if(r==null)return;int id=((Number)r.get("id")).intValue();if(id==Session.getUser().getUserId()){Dialogs.info("Not allowed","You cannot change your own account status.");return;}if(!Dialogs.confirm(title,question))return;try{usersDao.setStatus(id,status);dao.audit(Session.getUser().getUserId(),"USER_"+("BLOCKED".equals(status)?"BLOCKED":"UNBLOCKED"),"USER",id,"Account status changed to "+status);Dialogs.info(success,"The account status is now "+status+".");loadUsers();auditRows=dao.auditLogs();filterAudit();}catch(Exception e){Dialogs.error("Could not update user",e.getMessage());}}
    @FXML void refresh(){load();}
    @FXML void viewAssignment(){Map<String,Object> r=assignmentsTable.getSelectionModel().getSelectedItem();if(r==null){Dialogs.info("Select an assignment","Choose an assignment first.");return;}Dialogs.info("Assignment details","Assignment #"+r.get("assignment_id")+"\nRequest #"+r.get("request_id")+"\nTask: "+r.get("task_type")+"\nRequester: "+r.get("requester")+"\nVolunteer: "+r.get("volunteer")+"\nStatus: "+r.get("assignment_status")+"\nAssigned: "+r.get("assigned_at")+"\nCompleted: "+(r.get("completed_at")==null?"—":r.get("completed_at"))); }
    @FXML void viewFeedback(){Map<String,Object> r=feedbackTable.getSelectionModel().getSelectedItem();if(r==null){Dialogs.info("Select feedback","Choose feedback first.");return;}Dialogs.info("Feedback details","Feedback #"+r.get("feedback_id")+"\nRequest #"+r.get("request_id")+"\nRequester: "+r.get("requester")+"\nVolunteer: "+r.get("volunteer")+"\nRating: "+r.get("rating")+" / 5\n\n"+r.get("comment")); }
    @FXML void logout(){Session.clear();try{SceneManager.show("login.fxml","SupportSphere — Sign in");}catch(Exception ignored){}}
}
