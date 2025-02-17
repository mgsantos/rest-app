package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/messages")
public class MessageController {

    @Autowired
    private MessageService messageService;

    @PostMapping(consumes = "application/json", produces = "application/json")
    public Message createMessage(@RequestBody MessageRequest request) {
        return messageService.upsertMessage(null, request);
    }

    @PutMapping(value = "/{id}", consumes = "application/json", produces = "application/json")
    public ResponseEntity<Message> updateMessage(@PathVariable String id, @RequestBody MessageRequest request) {
        Message updatedMessage = messageService.upsertMessage(id, request);
        return ResponseEntity.ok(updatedMessage);
    }

    @GetMapping(produces = "application/json")
    public List<Message> getMessages() {
        return messageService.getAllMessages();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMessage(@PathVariable String id) {
        boolean isDeleted = messageService.deleteMessage(id);
        return isDeleted ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }



}