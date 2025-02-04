package com.atlassian.aim1;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;

@Entity
public class Message {

    @Id
    private String id;
    private String username;
    private String message;
    private Instant created;

    public Message() {
    }

    public Message(String id, String username, String message, Instant created) {
        this.id = id;
        this.username = username;
        this.message = message;
        this.created = created;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUser() {
        return username;
    }

    public void setUser(String username) {
        this.username = username;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public Instant getCreated() {
        return created;
    }

    public void setCreated(Instant created) {
        this.created = created;
    }
}