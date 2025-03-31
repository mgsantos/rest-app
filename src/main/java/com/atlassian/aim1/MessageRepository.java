package com.atlassian.aim1;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, String> {

    @Query("SELECT m FROM Message m WHERE m.message LIKE %:keyword%")
    List<Message> searchByMessage(@Param("keyword") String keyword);

}