package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import org.springframework.data.domain.Page;

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
    public Page<Message> findMessage(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortField,
            @RequestParam(defaultValue = "asc") String sortDirection) {
        if (keyword == null || keyword.isEmpty()) {
            return messageService.getAllMessages(page, size, sortField, sortDirection);
        } else {
            return messageService.findMessage(keyword, page, size, sortField, sortDirection);
        }
    }


    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMessage(@PathVariable String id) {
        boolean isDeleted = messageService.deleteMessage(id);
        return isDeleted ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }



}