#!/bin/bash

# Default number of iterations
iterations=20

# Parse command line arguments
while getopts "n:" opt; do
  case $opt in
    n) iterations=$OPTARG ;;
    *) echo "Usage: $0 [-n number_of_iterations]" >&2
       exit 1 ;;
  esac
done

# Output file
output_file="batchrunV4_output.txt"

# Run the command specified number of times
for ((i=1; i<=iterations; i++))
do
    echo "Run #$i" >> "$output_file"
    ./integration/DualLinkV4-test/DualLinkV4-test-vcs-ba-out/DualLinkV4-test-vcs-ba-exec -ucli -i ../utils/timing_checks/DualLinkV4-test-no-sync-xprop.ucli +long >> "$output_file"
    echo "" >> "$output_file"  # Add a newline for better readability
done

echo "Completed $iterations runs. Results are stored in $output_file."