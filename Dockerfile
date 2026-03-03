FROM debian:bookworm-slim
WORKDIR /app
COPY pkg /app/pkg
COPY static/ /app/static/
CMD ["/app/pkg"]
