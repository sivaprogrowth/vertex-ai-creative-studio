# Use an official Python runtime as a parent image
# Using slim variant for minimal attack surface
FROM python:3.13-slim

# Set the working directory in the container
WORKDIR /app

# Create a non-root user for running the application
# This is a security best practice to avoid running as root
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Install system dependencies required by OpenCV and other libraries
# libgl1 provides libGL.so.1 (runtime dependency)
# Using --no-install-recommends to minimize image size and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Copy the rest of the application code into the container
COPY . .

# Ensure proper ownership after copy
RUN chown -R appuser:appuser /app

# Install any needed packages specified in pyproject.toml (via uv)
RUN pip install --no-cache-dir uv
RUN uv sync

# Switch to non-root user before running application
USER appuser

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Add a health check endpoint for container orchestration
# Cloud Run uses this to determine if the service is healthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Define the command to run the app using gunicorn
# This is taken from the Procfile
CMD ["/app/.venv/bin/gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "8", "--timeout", "0", "-k", "uvicorn.workers.UvicornWorker", "main:app"]
