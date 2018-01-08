FROM openjdk:8-jre
MAINTAINER unai.perez

RUN mkdir -p /app
RUN wget http://static.druid.io/artifacts/releases/druid-0.11.0-bin.tar.gz -O /app/druid.tar.gz
RUN tar -xzf /app/druid.tar.gz -C /app
RUN mv /app/druid-0.11.0 /app/druid
RUN rm -f /app/druid.tar.gz

WORKDIR /app/druid

COPY start.sh .

EXPOSE 8081 8082 8083 8088 8090 8091 8100-8199
ENTRYPOINT ["/bin/bash", "start.sh"]
