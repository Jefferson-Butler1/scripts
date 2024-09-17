#!/bin/bash

# Get the current directory
current_dir=$(pwd)

# Function to activate virtual environment
activate_venv() {
    # Check for venv in the current directory
    if [ -d "venv" ]; then
        source venv/bin/activate
    elif [ -d ".venv" ]; then
        source .venv/bin/activate
    else
        echo "No virtual environment found. Using system Python."
        return 1
    fi
    return 0
}

# Activate virtual environment
if activate_venv; then
    echo "Virtual environment activated."
else
    echo "Proceeding with system Python."
fi

# Check if pytest is installed
if ! command -v pytest &> /dev/null
then
    echo "pytest is not installed. Please install it using 'pip install pytest'"
    exit 1
fi

# Run pytest for all files matching the pattern **/*.test.py
echo "Running Python tests in $current_dir and its subdirectories"
find "$current_dir" -type f -name "*.test.py" | xargs pytest -v

# Check the exit status
if [ $? -eq 0 ]; then
    echo "All tests passed successfully!"
else
    echo "Some tests failed. Please check the output above for details."
fi

# Deactivate virtual environment if it was activated
if [ -n "$VIRTUAL_ENV" ]; then
    deactivate
    echo "Virtual environment deactivated."
fi
