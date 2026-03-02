FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libsqlite3-0 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pkg /app/pkg
CMD ["/app/pkg"]
