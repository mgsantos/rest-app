# Build stage
FROM gradle:jdk21-noble AS build
WORKDIR /build
COPY src /build/src
COPY build.gradle /build/build.gradle
COPY gradlew /build/gradlew
COPY gradle /build/gradle
RUN chmod +x gradlew
RUN ./gradlew clean build --no-daemon

# Runtime stage
FROM eclipse-temurin:21-jdk-noble
COPY --from=build /build/build/libs/*.jar /opt/app.jar
CMD ["java", "-jar", "/opt/app.jar"]    