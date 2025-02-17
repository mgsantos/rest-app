package com.atlassian.aim1;

import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.util.Optional;
import java.time.Instant;

import java.time.Instant;

public class MessageServiceTest {

    @Mock
    private MessageRepository repository;

    @InjectMocks
    private MessageService messageService;

    @BeforeEach
    public void setUp() {
        MockitoAnnotations.openMocks(this);
    }

    @Test
    public void testUpsertMessage_WhenNoExistingMessage_ShouldInsertNewMessage() {
        // Arrange
        MessageRequest request = new MessageRequest();
        request.setUser("user1");
        request.setMessage("Hello, world!");

        // Mock the repository to return no existing message
        when(repository.findById(anyString())).thenReturn(Optional.empty());
        when(repository.save(any(Message.class))).thenAnswer(invocation -> invocation.getArgument(0)); // Mock save to return the saved message

        // Act
        Message savedMessage = messageService.upsertMessage("some-id", request);

        // Assert
        assertNotNull(savedMessage);
        assertEquals("user1", savedMessage.getUser());
        assertEquals("Hello, world!", savedMessage.getMessage());
        verify(repository).save(any(Message.class)); // Verify that save was called
    }

    @Test
    public void testUpsertMessage_WhenExistingMessage_ShouldUpdateMessage() {
        // Arrange
        String existingId = "existing-id";
        Message existingMessage = new Message(existingId, "user1", "Old message", Instant.now());
        MessageRequest request = new MessageRequest();
        request.setUser("user1");
        request.setMessage("Updated message");

        // Mock the repository to return the existing message
        when(repository.findById(existingId)).thenReturn(Optional.of(existingMessage));
        when(repository.save(any(Message.class))).thenAnswer(invocation -> invocation.getArgument(0)); // Mock save to return the updated message

        // Act
        Message updatedMessage = messageService.upsertMessage(existingId, request);

        // Assert
        assertNotNull(updatedMessage);
        assertEquals("user1", updatedMessage.getUser());
        assertEquals("Updated message", updatedMessage.getMessage());
        verify(repository).save(existingMessage); // Verify that save was called with the existing message
    }

}