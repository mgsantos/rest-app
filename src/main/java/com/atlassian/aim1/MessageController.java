package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/messages")
public class MessageController {

    @Autowired
    private MessageRepository repository;

    @PostMapping(consumes = "application/json", produces = "application/json")
    public Message createMessage(@RequestBody MessageRequest request) {

        Message message = new Message(
                UUID.randomUUID().toString(),
                request.getUser(),
                request.getMessage(),
                Instant.now()
        );
        return repository.save(message);
        // Message Service -> repository
        /// Controller -> upsert (update and insert) service -> DAO (repository)
        /// Business Logic
        /// Message Object -> does the object exist in the repository ? If exists, update, if it doesn't, insert it
    }

    @GetMapping(produces = "application/json")
    public List<Message> getMessages() {
        return repository.findAll();
    }
}

class MessageRequest {
    private String user;
    private String message;
    public String getUser() {
        return user;
    }
    public void setUser(String user) {
        this.user = user;
    }
    public String getMessage() {
        return message;
    }
    public void setMessage(String message) {
        this.message = message;
    }
}

// ADD POST MAPPING

// ADD PUT MAPPING

// ADD DELETE MAPPING