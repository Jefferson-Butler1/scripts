#!/bin/bash

# Get the current directory
current_dir=$PWD

# Function to create and activate virtual environment
create_and_activate_venv() {
    echo "Creating a fresh virtual environment..."
    # Remove existing .venv if it exists
    rm -rf .venv
    # Create new virtual environment
    python3 -m venv .venv
    # Activate the new virtual environment
    source .venv/bin/activate
    # Install requirements
    if [ -f "requirements.txt" ]; then
        echo "Installing requirements from requirements.txt..."
        pip install -r requirements.txt
    else
        echo "requirements.txt not found. Installing pytest..."
        pip install pytest
    fi
    return 0
}

# Create and activate virtual environment
if create_and_activate_venv; then
    echo "Virtual environment created and activated."
else
    echo "Failed to create or activate virtual environment. Exiting."
    exit 1
fi

# Add the project root to PYTHONPATH
export PYTHONPATH="$current_dir:$PYTHONPATH"

# Run pytest with improved discovery and verbose output
echo "Running Python tests in $current_dir"
pytest_output=$(pytest -v --tb=short -s --capture=no --color=yes "$current_dir/test" "$current_dir")
exit_status=$?

# Display pytest output with original colors
echo "$pytest_output"

# Display additional information with bat
echo -e "\nAdditional Information:" | bat --style=header --color=always
echo "$pytest_output" | grep -v '^\(======\|------\|______\)' | bat --style=plain --color=always

# Check the exit status
if [ $exit_status -eq 0 ]; then
    echo "All tests passed successfully!" | bat --style=header --color=always
else
    echo "Some tests failed. Please check the output above for details." | bat --style=header --color=always
fi
# Check the exit status
if [ $exit_status -eq 0 ]; then
    echo "All tests passed successfully!"
else
    echo "Some tests failed. Please check the output above for details."
fi

# Deactivate virtual environment
deactivate
echo "Virtual environment deactivated."

# Clean up the virtual environment
rm -rf .venv
echo "Virtual environment removed."

exit $exit_status
