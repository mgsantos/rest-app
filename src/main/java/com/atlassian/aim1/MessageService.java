package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class MessageService {

    @Autowired
    private MessageRepository repository;

    public Message upsertMessage(String id, MessageRequest request) {
        Message message;
        if (id == null) {
            // Create a new message since id is null
            message = new Message(UUID.randomUUID().toString(), request.getUser(), request.getMessage(), Instant.now());
            return repository.save(message);
        }

        Optional<Message> existingMessage = repository.findById(id);
        if (existingMessage.isPresent()) {
            message = existingMessage.get();
            message.setUser(request.getUser());
            message.setMessage(request.getMessage());
            message.setUpdated(Instant.now());
        } else {
            // If it doesn't exist, create a new message
            message = new Message(UUID.randomUUID().toString(), request.getUser(), request.getMessage(), Instant.now());
        }

        return repository.save(message);

    }

    public List<Message> getAllMessages() {
        return repository.findAll();
    }

    public boolean deleteMessage(String id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return true; // Successfully deleted
        }
        return false; // Message not found
    }
}