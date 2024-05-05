# Reference https://github.com/gleam-lang/example-echo-server/blob/main/Dockerfile
FROM erlang:alpine

RUN apk add curl

RUN curl -Lo gleam.tar.gz https://github.com/gleam-lang/gleam/releases/download/v1.1.0/gleam-v1.1.0-aarch64-unknown-linux-musl.tar.gz
RUN tar xf gleam.tar.gz
RUN mv gleam /bin

ENV SECRET_KEY_BASE ""

COPY gleam.toml gleam.toml
COPY manifest.toml manifest.toml
COPY src src
COPY priv priv
COPY tailwind.config.js tailwind.config.js

RUN gleam build
RUN gleam run -m tailwind/install
RUN gleam run -m tailwind/run

CMD ["gleam", "run"]
