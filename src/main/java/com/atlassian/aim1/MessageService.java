package com.atlassian.aim1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

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

    public Page<Message> findMessage(String keyword, int page, int size, String sortField, String sortDirection) {
        Sort sort = Sort.by(Sort.Direction.fromString(sortDirection), sortField);
        Pageable pageable = PageRequest.of(page, size, sort);
        return repository.searchByMessage(keyword, pageable);
    }

    public Page<Message> getAllMessages(int page, int size, String sortField, String sortDirection) {
        Sort sort = Sort.by(Sort.Direction.fromString(sortDirection), sortField);
        Pageable pageable = PageRequest.of(page, size, sort);
        return repository.findAll(pageable);
    }

    public boolean deleteMessage(String id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return true; // Successfully deleted
        }
        return false; // Message not found
    }
}