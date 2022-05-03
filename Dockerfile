FROM python:3.7

RUN pip install tox
RUN mkdir cairo-contracts
COPY . cairo-contracts
WORKDIR cairo-contracts
ENTRYPOINT tox
