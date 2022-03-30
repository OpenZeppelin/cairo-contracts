FROM ubuntu

RUN apt-get update && apt-get upgrade
RUN apt-get install -y python3 python3-pip libgmp3-dev git
RUN pip install tox
RUN mkdir cairo-contracts
COPY . cairo-contracts
WORKDIR cairo-contracts
ENTRYPOINT tox
