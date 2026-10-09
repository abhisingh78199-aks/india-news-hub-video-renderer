#!/bin/bash
set -e

echo "India News Hub FFmpeg Renderer"
echo "Checking FFmpeg..."

ffmpeg -version | head -n 1

mkdir -p /workspace/output

echo "Renderer environment is ready."
echo "Actual video inputs will be connected in the next integration step."

touch /workspace/output/renderer-test.txt

echo "Renderer test completed."
