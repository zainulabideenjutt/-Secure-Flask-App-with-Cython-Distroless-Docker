# Secure Flask App with Cython & Distroless Docker

## 📋 Table of Contents
- [What This Project Does](#what-this-project-does)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Step-by-Step Setup](#step-by-step-setup)
- [Understanding Each File](#understanding-each-file)
- [How Docker Build Works](#how-docker-build-works)
- [Running Your Application](#running-your-application)
- [Testing Your Application](#testing-your-application)

---

## 🎯 What This Project Does

This project creates a **secure Flask web application** with three layers of protection:

1. **Source Code Protection**: Your Python code is compiled into binary format using Cython, making it nearly impossible to read or reverse-engineer
2. **Minimal Attack Surface**: Uses Google's Distroless Docker image (no shell, no package managers, no unnecessary tools)
3. **Non-Root Execution**: Runs as a non-privileged user for enhanced security

**Real-World Use Case**: Perfect for deploying proprietary algorithms, business logic, or APIs where you want to protect your intellectual property.

---

## 📦 Prerequisites

### Required Software

1. **Docker Desktop** (includes Docker and Docker Compose)
   - **Windows**: Download from [docker.com](https://www.docker.com/products/docker-desktop)
   - **Mac**: Download from [docker.com](https://www.docker.com/products/docker-desktop)
   - **Linux**: Install Docker Engine and Docker Compose separately
   
   **Verify Installation**:
   ```bash
   docker --version
   docker-compose --version
   ```

2. **Text Editor** (choose one)
   - Visual Studio Code (recommended)
   - Sublime Text
   - Notepad++ (Windows)
   - Any code editor you prefer

3. **Python**
    - Download from [python.org](python.org)
    - verify with:
    ```
    python3 --version
    pip3 --version
    or
    python --version
    pip --version
    ```

### Required Knowledge (Beginner-Friendly!)

- Basic command line usage (opening terminal, navigating folders)
- Basic understanding of what a web server does
- No advanced Python or Docker knowledge needed - we'll explain everything!

---

## 📁 Project Structure

Create a new folder for your project (e.g., `flask-secure-app`). Inside it, create these files:

```
flask-secure-app/
│
├── app.py                 # Your Flask application (will be compiled)
├── run.py                 # Application entry point (starts the server)
├── setup.py               # Cython compilation configuration
├── requirements.txt       # Python packages needed
├── Dockerfile             # Instructions to build Docker image
├── docker-compose.yaml    # Easy Docker container management
└── .dockerignore          # Files to exclude from Docker build
```

---

## 🚀 Step-by-Step Setup

### Step 1: Create Your Project Folder

Open your terminal/command prompt and run:

```bash
# Create project folder
mkdir flask-secure-app
cd flask-secure-app
```

### Step 2: Create All Project Files

Create each file with the content below. You can use your text editor or create them via command line.

#### File 1: `app.py`

**Purpose**: This is your actual Flask web application. It will be compiled to binary.

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, World!'

if __name__ == '__main__':
    app.run(debug=True)
```

**What it does**:
- `Flask(__name__)`: Creates a Flask web application
- `@app.route('/')`: Defines the homepage URL
- `hello_world()`: Function that returns "Hello, World!" when someone visits your site
- `if __name__ == '__main__'`: Runs the app when you execute this file directly

---

#### File 2: `run.py`

**Purpose**: This is the entry point that starts your compiled application.

```python
import app
app.app.run(host="0.0.0.0", port=5000)
```

**What it does**:
- `import app`: Imports your compiled Flask application (the `.so` binary file)
- `app.app.run(...)`: Starts the Flask server
  - `host="0.0.0.0"`: Makes the server accessible from outside the container
  - `port=5000`: Runs on port 5000 (Flask's default)

**Why separate files?**
- `app.py` contains your business logic (gets compiled for security)
- `run.py` is the simple launcher (stays as plain Python)

---

#### File 3: `setup.py`

**Purpose**: Configuration file that tells Cython how to compile your Python code.

```python
from setuptools import setup
from Cython.Build import cythonize

setup(
    ext_modules = cythonize("app.py", compiler_directives={"language_level": "3"})
)
```

**What it does**:
- `cythonize("app.py", ...)`: Tells Cython to compile `app.py`
- `language_level: "3"`: Use Python 3 syntax
- Creates a `.so` file (shared object/binary) that Python can import

**The Magic**: After running this, `app.py` becomes a binary file (`.so`) that:
- ✅ Can be imported and run by Python
- ❌ Cannot be read or edited with a text editor
- ❌ Cannot be easily reverse-engineered

---

#### File 4: `requirements.txt`

**Purpose**: Lists all Python packages your project needs.

```
Cython
Flask
setuptools
wheel
```

**What each package does**:
- **Cython**: Compiles Python to C/binary (for source code protection)
- **Flask**: Web framework to create your web application
- **setuptools**: Tools for building Python packages
- **wheel**: Helps create distributable Python packages

---

#### File 5: `Dockerfile`

**Purpose**: Instructions for Docker to build your application container.

Create this file named Dockerfile with the content provided below (the extensively commented Dockerfile). 
```
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
```
The file has two main stages:

**Stage 1 - Builder** (lines 1-70):
- Installs build tools (gcc, compilers)
- Installs Python dependencies
- Compiles your Python code to binary
- Deletes source code after compilation

**Stage 2 - Runtime** (lines 71-end):
- Uses minimal distroless image
- Copies only compiled binary and dependencies
- Runs as non-root user
- No shell, no package managers (maximum security)

---

#### File 6: `docker-compose.yaml`

**Purpose**: Simplifies Docker container management with a single command.

```yaml
services:
  flask_app:
    build:
      context: .
      dockerfile: Dockerfile
    image: flask-image:1.0
    container_name: flask_app
    ports:
      - "5000:5000"
    restart: always
```

**What it does**:
- `build`: Tells Docker where to find the Dockerfile
- `image: flask-image:1.0`: Names your Docker image
- `container_name: flask_app`: Names the running container
- `ports: "5000:5000"`: Maps container port 5000 to your computer's port 5000
  - First 5000: Your computer's port
  - Second 5000: Container's port
- `restart: always`: Automatically restarts if the container crashes

---

#### File 7: `.dockerignore`

**Purpose**: Tells Docker which files to ignore during build (makes builds faster and more secure).

```
# Ignore Python cache and compiled files
__pycache__/
*.pyc
*.pyo

# Ignore virtual environments
.venv/
env/

# Ignore build artifacts
build/
dist/
*.egg-info/
*.c
*.so
*.pyd

# Ignore Git and editor files
.git/
.gitignore
*.log
*.swp
*.DS_Store
*.idea/
.vscode/

# Ignore Docker's own build cache folder (if any)
.dockerignore
Dockerfile
docker-compose.yaml
```

**Why this matters**:
- Prevents accidentally copying sensitive files (like `.env` with passwords)
- Makes Docker builds faster by excluding unnecessary files
- Reduces final image size

---

## 🏗️ How Docker Build Works

### The Two-Stage Build Process

#### Stage 1: Builder (The Workshop)

Think of this as a workshop where you have all the tools:

```
┌─────────────────────────────────────┐
│  BUILDER STAGE                      │
│  (python:3.11.2-slim)               │
├─────────────────────────────────────┤
│  Tools Available:                   │
│  ✓ gcc compiler                     │
│  ✓ pip package manager              │
│  ✓ build tools                      │
│                                     │
│  Process:                           │
│  1. Install dependencies            │
│  2. Copy source code (app.py)       │
│  3. Compile to binary (app.so)      │
│  4. Delete source code              │
└─────────────────────────────────────┘
           │
           │ Copy only:
           │ • Compiled binary (.so)
           │ • Python packages
           │ • run.py
           ▼
┌─────────────────────────────────────┐
│  RUNTIME STAGE                      │
│  (distroless/python3)               │
├─────────────────────────────────────┤
│  Tools Available:                   │
│  ✓ Python runtime ONLY              │
│  ✗ No shell                         │
│  ✗ No package managers              │
│  ✗ No build tools                   │
│                                     │
│  Contains:                          │
│  • Your compiled app                │
│  • Minimal Python runtime           │
│  • Required libraries only          │
└─────────────────────────────────────┘
```

#### Why Two Stages?

**Security & Size Benefits**:
- Builder stage: ~500 MB (with all tools)
- Runtime stage: ~150 MB (minimal)
- Attacker can't find: source code, compilers, package managers, shell

---

## 🎬 Running Your Application

### Method 1: Using Docker Compose (Recommended for Beginners)

Docker Compose makes everything easy with a single command!

```bash
# Navigate to your project folder
cd flask-secure-app

# Build and start the container
docker-compose up --build
```

**What happens**:
1. Docker reads `docker-compose.yaml`
2. Builds your Docker image using the Dockerfile
3. Compiles your Python code to binary
4. Creates and starts a container
5. Your app is now running!

**You'll see output like**:
```
[+] Building 45.2s
[+] Running 1/1
 ✔ Container flask_app  Started
flask_app  |  * Running on http://0.0.0.0:5000
flask_app  |  * Running on http://127.0.0.1:5000
```

**To stop the container**:
```bash
# Press Ctrl+C, then run:
docker-compose down
```

**To run in background (detached mode)**:
```bash
docker-compose up -d
```

---

### Method 2: Using Docker Commands Directly

If you prefer manual control:

```bash
# Build the Docker image
docker build -t flask-image:1.0 .

# Run the container
docker run -d -p 5000:5000 --name flask_app flask-image:1.0

# View logs
docker logs flask_app

# Stop the container
docker stop flask_app

# Remove the container
docker rm flask_app
```

---

## 🧪 Testing Your Application

### 1. Open Your Web Browser

Navigate to:
```
http://localhost:5000
```

You should see:
```
Hello, World!
```

### 2. Test with cURL (Command Line)

```bash
curl http://localhost:5000
```

Output:
```
Hello, World!
```

### 3. Verify Source Code Protection

Try to find your source code inside the container:

```bash
# Enter the container (this will fail because there's no shell in distroless!)
docker exec -it flask_app /bin/bash
# Error: executable file not found in $PATH

docker exec -it flask_app /bin/sh
# Error: executable file not found in $PATH
```
Try to Export Container files system using **docker export**
```
docker export flask_app -o flask_app_fs.tar
# Takes everything inside your running container (the container’s internal files and folders)
and saves it as a single .tar file (like a zip).
```

On Extraction You'll see:
```
app.cpython-311-x86_64-linux-gnu.so  # Your compiled binary
run.py                               # Entry point
site-packages/                       # Dependencies
```

**Notice**: No `app.py` source code! It's been compiled and deleted.

---

## 🔍 Understanding the Complete Flow

### Development to Deployment Journey

```
┌──────────────────────────────────────────────────────────────┐
│ 1. DEVELOPMENT PHASE                                         │
│    You write: app.py (source code in Python)                 │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. DOCKER BUILD STARTS                                       │
│    Docker reads: Dockerfile and docker-compose.yaml          │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. BUILDER STAGE                                             │
│    ┌────────────────────────────────────────────────┐        │
│    │ a. Install gcc, build tools                    │        │
│    │ b. Install Python packages (Flask, Cython)     │        │
│    │ c. Copy app.py, setup.py, run.py               │        │
│    │ d. Run: python setup.py build_ext --inplace    │        │
│    │    → Cython converts app.py to app.c           │        │
│    │    → gcc compiles app.c to app.so (binary)     │        │
│    │ e. Delete app.py, app.c, setup.py              │        │
│    └────────────────────────────────────────────────┘        │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. RUNTIME STAGE                                             │
│    ┌────────────────────────────────────────────────┐        │
│    │ a. Start from distroless Python image          │        │
│    │ b. Copy app.so (binary) from builder           │        │
│    │ c. Copy site-packages from builder             │        │
│    │ d. Copy run.py from builder                    │        │
│    │ e. Set environment variables                   │        │
│    │ f. Switch to non-root user                     │        │
│    └────────────────────────────────────────────────┘        │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. CONTAINER STARTS                                          │
│    Command: python3.11 run.py                                │
│    ┌────────────────────────────────────────────────┐        │
│    │ run.py executes:                               │        │
│    │   import app  ← Loads compiled app.so binary   │        │
│    │   app.app.run(host="0.0.0.0", port=5000)       │        │
│    └────────────────────────────────────────────────┘        │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. APPLICATION RUNNING                                       │
│    Flask server listens on http://0.0.0.0:5000               │
│    Accessible at: http://localhost:5000                      │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Features Explained

### 1. Source Code Protection (Cython)

**Before Compilation** (`app.py`):
```python
# Anyone can read this:
from flask import Flask
app = Flask(__name__)
@app.route('/')
def hello_world():
    return 'Hello, World!'
```

**After Compilation** (`app.so` - binary file):
```
ELF binary (unreadable gibberish)
7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
03 00 3e 00 01 00 00 00 50 1f 00 00 00 00 00 00
...
```

**Benefits**:
- ✅ Protects proprietary algorithms
- ✅ Prevents code theft
- ✅ Makes reverse engineering extremely difficult

---

### 2. Traditional Docker Image VS Distroless Image

**Traditional Docker Image**:
```
Ubuntu/Debian Base Image
├── Shell (bash, sh)
├── Package Managers (apt, dpkg)
├── System Utilities (ls, cat, grep)
├── Network Tools
└── Your Application
Size: ~500 MB
Attack Surface: HIGH
```

**Distroless Image**:
```
Distroless Base Image
├── Python Runtime ONLY
└── Your Application
Size: ~150 MB
Attack Surface: MINIMAL
```

**Benefits**:
- ✅ 70% smaller image size
- ✅ No shell = attackers can't execute commands
- ✅ No package managers = can't install malware
- ✅ Minimal attack surface
- ✅ Faster deployment

---

### 3. Non-Root User

**Running as Root (Bad)**:
```
If container is compromised:
└── Attacker has ROOT privileges
    ├── Can modify ANY file
    ├── Can install backdoors
    └── Can access host system (in some cases)
```

**Running as Non-Root (Good)**:
```
If container is compromised:
└── Attacker has LIMITED privileges
    ├── Cannot modify system files
    ├── Cannot install software
    └── Restricted access
```

---

## 🎓 Next Steps & Customization

### Adding More Routes

Edit `app.py` before building:

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, World!'

@app.route('/api/data')
def get_data():
    return jsonify({"status": "success", "data": [1, 2, 3]})

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200
```

Then rebuild:
```bash
docker-compose down
docker-compose up --build
```
Test Endpoints:
```
http://localhost:5000/api/data
http://localhost:5000/health
```
You Should see for **/api/data**:
```
{
   "status":"success",
   "data":[
      1,
      2,
      3
   ]
}
```
You Should see for **/health**:
```
{
   "status":"healthy"
}
```
---

### Adding Dependencies

Edit `requirements.txt`:
```
Cython
Flask
setuptools
wheel
requests      # Add new packages
sqlalchemy
redis
```

Then rebuild the image.

---

## 📚 Additional Resources

### Official Documentation
- **Flask**: https://flask.palletsprojects.com/
- **Cython**: https://cython.readthedocs.io/
- **Docker**: https://docs.docker.com/
- **Distroless**: https://github.com/GoogleContainerTools/distroless

### Learning Resources
- **Docker for Beginners**: https://www.tutorialspoint.com/docker/index.htm

---

## 🎉 Congratulations!

You've successfully created a secure, production-ready Flask application with:

✅ Source code protection via Cython compilation  
✅ Minimal attack surface using distroless images  
✅ Non-root execution for enhanced security  
✅ Easy deployment with Docker Compose  
✅ Professional project structure  

**Your application is now ready for deployment!**

---

**Questions or Issues?**  
Check the Common Issues section above or consult the official documentation links provided.

Happy coding! 🚀