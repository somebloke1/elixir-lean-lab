#!/usr/bin/env python3
"""
Test Alpine Docker builder with the hello_world example application.
"""

import os
import subprocess
import shutil
from pathlib import Path

def run_command(cmd, check=True, cwd=None):
    """Run a shell command and return the result."""
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    if check and result.returncode != 0:
        print(f"Error running command: {cmd}")
        print(f"stdout: {result.stdout}")
        print(f"stderr: {result.stderr}")
        raise subprocess.CalledProcessError(result.returncode, cmd)
    return result

def create_dockerfile_with_app():
    """Create a Dockerfile that includes the hello_world app."""
    
    dockerfile_content = """
# Multi-stage build for minimal Elixir VM with hello_world app
# Stage 1: Builder
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base nodejs npm python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy hello_world application
COPY examples/hello_world .

# Get dependencies and compile
ENV MIX_ENV=prod
RUN mix deps.get
RUN mix compile
RUN mix release

# Stage 2: Runtime
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs zlib

# Create non-root user
RUN addgroup -g 1000 elixir && \
    adduser -u 1000 -G elixir -s /bin/sh -D elixir

WORKDIR /app

# Copy Erlang/Elixir runtime from builder
COPY --from=builder /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=builder /usr/local/lib/elixir /usr/local/lib/elixir
COPY --from=builder /usr/local/bin/erl /usr/local/bin/
COPY --from=builder /usr/local/bin/erlc /usr/local/bin/
COPY --from=builder /usr/local/bin/elixir /usr/local/bin/
COPY --from=builder /usr/local/bin/elixirc /usr/local/bin/
COPY --from=builder /usr/local/bin/iex /usr/local/bin/
COPY --from=builder /usr/local/bin/mix /usr/local/bin/

# Copy application release
COPY --from=builder /app/_build/prod/rel/hello_world ./

# Set up environment
ENV LANG=C.UTF-8
ENV PATH="/usr/local/bin:$PATH"
ENV ERL_LIBS="/usr/local/lib/elixir/lib"
ENV ERL_AFLAGS="-kernel shell_history enabled"

# Fix permissions
USER root
RUN chmod +x /usr/local/bin/* && \
    chown -R elixir:elixir /usr/local/lib/elixir && \
    chown -R elixir:elixir /usr/local/lib/erlang && \
    chown -R elixir:elixir /app
USER elixir

# Start the application
CMD ["./bin/hello_world", "start"]

# Stage 3: VM Export
FROM scratch AS export
COPY --from=runtime / /
"""
    
    # Create build directory
    build_dir = Path("./build")
    build_dir.mkdir(exist_ok=True)
    
    dockerfile_path = build_dir / "Dockerfile.app"
    dockerfile_path.write_text(dockerfile_content)
    
    print(f"✅ Generated Dockerfile with app at {dockerfile_path}")
    return dockerfile_path

def test_app_build(dockerfile_path):
    """Test building VM with hello_world app."""
    
    image_name = "elixir-lean-vm-hello"
    
    try:
        # Build from project root so we can access examples/hello_world
        cmd = f"docker build -t {image_name} -f {dockerfile_path} ."
        result = run_command(cmd, cwd=".")
        
        print(f"✅ Docker build with app completed successfully")
        
        # Check image size
        result = run_command(f"docker images {image_name} --format 'table {{{{.Size}}}}'")
        print(f"App image size: {result.stdout.strip()}")
        
        return image_name
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Docker build with app failed: {e}")
        return None

def test_app_run(image_name):
    """Test running the hello_world application."""
    
    if not image_name:
        print("❌ No image to test")
        return False
    
    try:
        # Debug: Check what's in the app directory
        print("🔍 Debugging application structure...")
        cmd = f"docker run --rm {image_name} ls -la /app"
        result = run_command(cmd, check=False)
        print(f"App directory contents: {result.stdout.strip()}")
        
        cmd = f"docker run --rm {image_name} ls -la /app/bin"
        result = run_command(cmd, check=False)
        print(f"App bin directory: {result.stdout.strip()}")
        
        # Try running the app manually
        print("🚀 Testing hello_world application...")
        cmd = f"docker run --rm {image_name} /app/bin/hello_world start"
        result = run_command(cmd, check=False)
        
        if result.returncode == 0:
            print(f"✅ Application output:")
            print(result.stdout.strip())
            
            # Check for expected output
            if "Hello from minimal Elixir VM!" in result.stdout:
                print("✅ Application produced expected output")
                return True
            else:
                print("❌ Application output unexpected")
                return False
        else:
            print(f"❌ Application failed to run:")
            print(f"stdout: {result.stdout.strip()}")
            print(f"stderr: {result.stderr.strip()}")
            
            # Try alternative approaches
            print("🔍 Trying alternative execution methods...")
            
            # Try starting with shell
            cmd = f"docker run --rm {image_name} /bin/sh -c 'cd /app && ./bin/hello_world start'"
            result = run_command(cmd, check=False)
            if result.returncode == 0:
                print(f"✅ Alternative execution successful:")
                print(result.stdout.strip())
                return True
            else:
                print(f"❌ Alternative execution failed: {result.stderr.strip()}")
            
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"❌ App run test failed: {e}")
        return False

def export_and_compress(image_name):
    """Export and compress the VM image."""
    
    if not image_name:
        return None
    
    output_path = "./build/alpine-vm-hello.tar"
    
    try:
        # Export the Docker image
        cmd = f"docker save -o {output_path} {image_name}"
        run_command(cmd)
        
        # Check file size
        size_bytes = os.path.getsize(output_path)
        size_mb = size_bytes / (1024 * 1024)
        
        print(f"✅ VM with app exported: {size_mb:.2f} MB")
        
        # Compress with XZ
        if shutil.which("xz"):
            compressed_path = output_path + ".xz"
            run_command(f"xz -9 -k {output_path}")
            if os.path.exists(compressed_path):
                compressed_size = os.path.getsize(compressed_path)
                compressed_mb = compressed_size / (1024 * 1024)
                compression_ratio = (1 - compressed_size / size_bytes) * 100
                print(f"✅ Compressed VM: {compressed_mb:.2f} MB ({compression_ratio:.1f}% reduction)")
                return compressed_path
        
        return output_path
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Export failed: {e}")
        return None

def cleanup(image_name):
    """Clean up test artifacts."""
    
    if image_name:
        run_command(f"docker rmi {image_name}", check=False)
    
    artifacts = [
        "./build/Dockerfile.app",
        "./build/alpine-vm-hello.tar",
        "./build/alpine-vm-hello.tar.xz"
    ]
    
    for artifact in artifacts:
        if os.path.exists(artifact):
            os.remove(artifact)
            print(f"🧹 Cleaned up {artifact}")

def main():
    """Test Alpine builder with hello_world application."""
    
    print("🚀 Testing Alpine builder with hello_world application...")
    print("=" * 60)
    
    try:
        # Test 1: Create Dockerfile with app
        print("\n📋 Test 1: Dockerfile Generation (with app)")
        dockerfile_path = create_dockerfile_with_app()
        
        # Test 2: Build VM with app
        print("\n🔨 Test 2: Docker Build (with app)")
        image_name = test_app_build(dockerfile_path)
        
        # Test 3: Run the application
        print("\n🏃 Test 3: Application Execution")
        app_success = test_app_run(image_name)
        
        # Test 4: Export and compress
        print("\n📦 Test 4: VM Export and Compression")
        exported_vm = export_and_compress(image_name)
        
        # Cleanup
        print("\n🧹 Cleanup")
        cleanup(image_name)
        
        # Summary
        print("\n" + "=" * 60)
        print("📊 Application Test Summary:")
        print(f"  Dockerfile with app: ✅")
        print(f"  Docker build: {'✅' if image_name else '❌'}")
        print(f"  Application run: {'✅' if app_success else '❌'}")
        print(f"  VM export: {'✅' if exported_vm else '❌'}")
        
        if image_name and app_success and exported_vm:
            print("\n🎉 Alpine builder successfully creates minimal VMs with Elixir applications!")
            return True
        else:
            print("\n❌ Some tests failed.")
            return False
            
    except Exception as e:
        print(f"\n💥 Test failed with exception: {e}")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)