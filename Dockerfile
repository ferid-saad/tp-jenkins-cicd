# FROM openjdk:8-jdk-alpine
FROM openjdk:17-jdk-slim
VOLUME /tmp
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar /app.jar
CMD ["java","-jar","/app.jar"]
EXPOSE 2222
