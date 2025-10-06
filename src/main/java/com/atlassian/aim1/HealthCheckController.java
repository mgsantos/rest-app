package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import org.springframework.data.domain.Page;

@RestController
@RequestMapping("/health")
public class HealthCheckController {

    @Autowired
    private HealthCheckService healthCheckService;

    @GetMapping(produces = "application/json")
    public HealthCheck addCheck( ) {
        return healthCheckService.insertCheck( );
    }

}