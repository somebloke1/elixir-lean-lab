#!/usr/bin/env python3
"""
Quick test of Alpine Docker builder functionality.
This bypasses Mix and tests the core Docker build process directly.
"""

import os
import subprocess
import json
import tempfile
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

def test_alpine_dockerfile_generation():
    """Test that we can generate a valid Dockerfile for Alpine builds."""
    
    # Create a simplified Dockerfile based on the Alpine builder logic
    dockerfile_content = """
# Multi-stage build for minimal Elixir VM
# Stage 1: Builder
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base nodejs npm python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

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

USER elixir

# Set up environment
ENV LANG=C.UTF-8
ENV ERL_AFLAGS="-kernel shell_history enabled"
ENV PATH="/usr/local/bin:$PATH"
ENV ERL_LIBS="/usr/local/lib/elixir/lib"

CMD ["iex"]

# Stage 3: VM Export (using scratch for minimal size)
FROM scratch AS export
COPY --from=runtime / /
"""
    
    # Create build directory
    build_dir = Path("./build")
    build_dir.mkdir(exist_ok=True)
    
    dockerfile_path = build_dir / "Dockerfile"
    dockerfile_path.write_text(dockerfile_content)
    
    print(f"✅ Generated Dockerfile at {dockerfile_path}")
    return dockerfile_path

def test_docker_build(dockerfile_path):
    """Test the Docker build process."""
    
    image_name = "elixir-lean-vm-test"
    build_dir = dockerfile_path.parent
    
    try:
        # Build the Docker image (use . as context since we're in the build directory)
        cmd = f"docker build -t {image_name} -f Dockerfile ."
        result = run_command(cmd, cwd=build_dir)
        
        print(f"✅ Docker build completed successfully")
        
        # Check the image size
        result = run_command(f"docker images {image_name} --format 'table {{{{.Size}}}}'")
        print(f"Docker image size: {result.stdout.strip()}")
        
        return image_name
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Docker build failed: {e}")
        return None

def test_docker_export(image_name):
    """Test exporting the Docker image."""
    
    if not image_name:
        print("❌ No image to export")
        return None
    
    output_path = "./build/alpine-vm-test.tar"
    
    try:
        # Export the Docker image
        cmd = f"docker save -o {output_path} {image_name}"
        run_command(cmd)
        
        # Check file size
        size_bytes = os.path.getsize(output_path)
        size_mb = size_bytes / (1024 * 1024)
        
        print(f"✅ Image exported to {output_path}")
        print(f"Exported size: {size_mb:.2f} MB ({size_bytes} bytes)")
        
        # Test compression
        compressed_path = output_path + ".xz"
        if shutil.which("xz"):
            run_command(f"xz -9 -k {output_path}")
            if os.path.exists(compressed_path):
                compressed_size = os.path.getsize(compressed_path)
                compressed_mb = compressed_size / (1024 * 1024)
                compression_ratio = (1 - compressed_size / size_bytes) * 100
                print(f"✅ Compressed to {compressed_path}")
                print(f"Compressed size: {compressed_mb:.2f} MB ({compression_ratio:.1f}% reduction)")
        else:
            print("⚠️  xz not available for compression test")
        
        return output_path
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Docker export failed: {e}")
        return None

def test_docker_run(image_name):
    """Test running the Docker image."""
    
    if not image_name:
        print("❌ No image to test")
        return False
    
    try:
        # First debug: check what's in the container
        print("🔍 Debugging container contents...")
        
        cmd = f"docker run --rm -i {image_name} ls -la /usr/local/bin/"
        result = run_command(cmd, check=False)
        print(f"Binaries in /usr/local/bin/: {result.stdout.strip()}")
        
        cmd = f"docker run --rm -i {image_name} ls -la /usr/local/lib/"
        result = run_command(cmd, check=False)
        print(f"Libraries in /usr/local/lib/: {result.stdout.strip()}")
        
        # Test basic shell
        cmd = f"docker run --rm -i {image_name} /bin/sh -c 'echo Hello from container'"
        result = run_command(cmd)
        print(f"✅ Basic shell test: {result.stdout.strip()}")
        
        # Test erl directly
        cmd = f"docker run --rm -i {image_name} erl -version"
        result = run_command(cmd, check=False)
        if result.returncode == 0:
            print(f"✅ Erlang version: {result.stdout.strip()}")
        else:
            print(f"❌ Erlang test failed: {result.stderr.strip()}")
        
        # Try iex instead
        cmd = f'docker run --rm -i {image_name} iex -e "IO.puts(\\"Hello from IEx!\\")" --halt'
        result = run_command(cmd, check=False)
        if result.returncode == 0:
            print(f"✅ IEx test: {result.stdout.strip()}")
            return True
        else:
            print(f"❌ IEx test failed: {result.stderr.strip()}")
            return False
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Docker run test failed: {e}")
        return False

def cleanup_test_artifacts():
    """Clean up test artifacts."""
    
    artifacts = [
        "./build/Dockerfile",
        "./build/alpine-vm-test.tar",
        "./build/alpine-vm-test.tar.xz"
    ]
    
    for artifact in artifacts:
        if os.path.exists(artifact):
            os.remove(artifact)
            print(f"🧹 Cleaned up {artifact}")

def main():
    """Run the Alpine builder test suite."""
    
    print("🚀 Testing Alpine Docker builder functionality...")
    print("=" * 50)
    
    try:
        # Test 1: Dockerfile generation
        print("\n📋 Test 1: Dockerfile Generation")
        dockerfile_path = test_alpine_dockerfile_generation()
        
        # Test 2: Docker build
        print("\n🔨 Test 2: Docker Build")
        image_name = test_docker_build(dockerfile_path)
        
        # Test 3: Docker export
        print("\n📦 Test 3: Docker Export")
        exported_image = test_docker_export(image_name)
        
        # Test 4: Docker run
        print("\n🏃 Test 4: Docker Run Test")
        run_success = test_docker_run(image_name)
        
        # Clean up
        print("\n🧹 Cleanup")
        if image_name:
            run_command(f"docker rmi {image_name}", check=False)
        cleanup_test_artifacts()
        
        # Summary
        print("\n" + "=" * 50)
        print("📊 Test Summary:")
        print(f"  Dockerfile generation: ✅")
        print(f"  Docker build: {'✅' if image_name else '❌'}")
        print(f"  Docker export: {'✅' if exported_image else '❌'}")
        print(f"  Docker run: {'✅' if run_success else '❌'}")
        
        if image_name and exported_image and run_success:
            print("\n🎉 All tests passed! Alpine builder is functional.")
            return True
        else:
            print("\n❌ Some tests failed. Check output above.")
            return False
            
    except Exception as e:
        print(f"\n💥 Test suite failed with exception: {e}")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)