FROM ghcr.io/gleam-lang/gleam:v1.2.1-erlang-alpine

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
