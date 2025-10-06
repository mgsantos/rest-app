package com.atlassian.aim1;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;

@Entity
public class HealthCheck {

    @Id
    private String id;
    private Instant created;

    public HealthCheck() {
    }

    public HealthCheck(String id, Instant created) {
        this.id = id;
        this.created = created;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public Instant getCreated() {
        return created;
    }

    public void setCreated(Instant created) {
        this.created = created;
    }

}