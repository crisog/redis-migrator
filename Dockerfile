FROM ubuntu:jammy

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y redis build-essential python3 python3-pip

ENV PYTHONUNBUFFERED=1
RUN pip3 install rdbtools python-lzf

WORKDIR app

ADD . .

CMD bash migrate.sh
