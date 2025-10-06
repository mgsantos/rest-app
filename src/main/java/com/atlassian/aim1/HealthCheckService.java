package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Service
public class HealthCheckService {

    @Autowired
    private HealthCheckRepository repository;

    public HealthCheck insertCheck( ) {
        HealthCheck check;
        check = new HealthCheck(UUID.randomUUID().toString(), Instant.now());
        return repository.save(check);

    }

}