FROM golang:1.23.8-bullseye

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y redis \
    && go install github.com/hdt3213/rdb@latest

WORKDIR /app

COPY --chmod=755 migrate.sh ./

CMD bash migrate.sh