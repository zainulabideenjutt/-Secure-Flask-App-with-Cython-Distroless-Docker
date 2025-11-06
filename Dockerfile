# ============================================================================
# STAGE 1: BUILD STAGE
# ============================================================================
# Purpose: 
# - Compile Python source code to Cython binary (.so file)
# - Install all Python dependencies
# - This stage contains build tools (gcc, pip, etc.) that won't be in final image
# ============================================================================
FROM python:3.11.2-slim AS builder

# Set working directory for all build operations
WORKDIR /app

# ----------------------------------------------------------------------------
# Install System Build Dependencies
# ----------------------------------------------------------------------------
# gcc:              C compiler required to compile Cython code
# build-essential:  Compilation tools (make, g++, libc-dev, etc.)
# --no-install-recommends: Installs only essential packages, reduces image size
# rm -rf /var/lib/apt/lists/*: Cleans apt cache to reduce layer size
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc build-essential && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------------
# Install Python Dependencies
# ----------------------------------------------------------------------------
# Copy requirements.txt FIRST before other files for better Docker layer caching
# If requirements.txt doesn't change, Docker reuses this cached layer
# This speeds up rebuilds when only application code changes
COPY requirements.txt .

# Install all Python packages (Flask, Cython, etc.)
# --no-cache-dir: Don't store pip cache, reduces image size
# Packages installed to default location: /usr/local/lib/python3.11/site-packages
RUN pip install --no-cache-dir -r requirements.txt 

# ----------------------------------------------------------------------------
# Copy Application Source Code
# ----------------------------------------------------------------------------
# Copy all application files including:
# - app.py: Your Flask application (will be compiled to binary)
# - setup.py: Cython build configuration script
# - run.py: Application entry point (will be kept)
COPY . .

# ----------------------------------------------------------------------------
# Compile Python to Cython Binary
# ----------------------------------------------------------------------------
# This is the security feature that protects your source code:
# 1. setup.py reads app.py
# 2. Cython converts app.py to C code (app.c)
# 3. GCC compiles app.c to binary shared object (app.cpython-311-x86_64-linux-gnu.so)
# 4. The .so file can be imported like a Python module but can't be easily reversed
#
# --inplace: Creates the .so file in the current directory alongside source
RUN python setup.py build_ext --inplace

# ----------------------------------------------------------------------------
# Security Cleanup: Remove Source Code
# ----------------------------------------------------------------------------
# Delete original Python source and intermediate C files
# After compilation, these files are no longer needed and shouldn't be in production
# Keeps only:
# - Compiled .so binary (the compiled version of app.py)
# - run.py (entry point that imports the compiled binary)
RUN rm -f app.py app.c setup.py requirements.txt && \
    rm -rf build/ && \
    pip uninstall -y cython wheel setuptools


# ============================================================================
# STAGE 2: RUNTIME STAGE (PRODUCTION)
# ============================================================================
# Purpose:
# - Minimal, secure production image using Google's distroless base
# - Contains only: Python runtime + your app + dependencies
# - NO package managers, NO shell, NO build tools = smaller attack surface
# ============================================================================

FROM gcr.io/distroless/python3-debian12

# Set working directory for the application
WORKDIR /app

# ----------------------------------------------------------------------------
# Copy Application Files from Builder
# ----------------------------------------------------------------------------
# Copy everything from /app in builder stage
# This includes:
# - *.so file (compiled Cython binary)
# - run.py (entry point)
# - Any other runtime files
# Note: Does NOT include app.py, app.c, setup.py (already deleted)
COPY --from=builder /app /app

# ----------------------------------------------------------------------------
# Copy Python Dependencies from Builder
# ----------------------------------------------------------------------------
# Copy all installed Python packages (Flask, Werkzeug, Jinja2, etc.)
# FROM: /usr/local/lib/python3.11/site-packages (builder's pip install location)
# TO: /app/site-packages (custom location in production)
# This includes all packages from requirements.txt
COPY --from=builder /usr/local/lib/python3.11/site-packages /app/site-packages

# ----------------------------------------------------------------------------
# Configure Python Environment
# ----------------------------------------------------------------------------
# PYTHONPATH tells Python where to search for modules
# Order matters - Python searches left to right:
# 1. /app/site-packages: Find Flask and other dependencies
# 2. /app: Find our application code (run.py, compiled .so files)
ENV PYTHONPATH="/app/site-packages:/app"

# ----------------------------------------------------------------------------
# Security: Use Non-Root User
# ----------------------------------------------------------------------------
# Distroless provides a non-root user 'nonroot' with limited permissions
# Running as non-root reduces risk if the container is compromised
# Switch to 'nonroot' user for all subsequent commands
USER nonroot

# ----------------------------------------------------------------------------
# Container Network Configuration
# ----------------------------------------------------------------------------
# Expose port 5000 (Flask's default port)
# This is documentation only - doesn't actually publish the port
# Use 'docker run -p 5000:5000' to publish the port
EXPOSE 5000

# ----------------------------------------------------------------------------
# Container Startup Command
# ----------------------------------------------------------------------------
# Run the application using distroless's Python interpreter
# Distroless sets /usr/bin/python3.11 as the default entrypoint
# It will execute: /usr/bin/python3.11 run.py
# 
# run.py should:
# 1. Import the compiled binary: from app import app (or similar)
# 2. Start Flask: app.run(host='0.0.0.0', port=5000)
CMD ["run.py"]