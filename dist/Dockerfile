FROM ubuntu:16.04
ARG executable
RUN apt-get update && apt-get install -y libgmp-dev netbase
COPY ${executable} /opt/service/run
WORKDIR /opt/service
ENTRYPOINT ["./run"]
