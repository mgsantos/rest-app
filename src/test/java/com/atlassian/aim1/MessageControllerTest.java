package com.atlassian.aim1;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class MessageControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    public void testCreateMessage() throws Exception {
        String json = "{\"user\":\"foo\", \"message\":\"bar\"}";

        mockMvc.perform(post("/messages")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value("foo"))
                .andExpect(jsonPath("$.message").value("bar"));
    }

    @Test
    public void testGetMessages() throws Exception {
        mockMvc.perform(get("/messages")
                .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").isNumber());
    }

    // Unit test for the upsert service
    /// mock repository for the service (upsert GET and checks if it exists, or not, depending on the results insert or update)
    /// upsert.method (message)
    /// https://site.mockito.org/

    // Add integration tests

}