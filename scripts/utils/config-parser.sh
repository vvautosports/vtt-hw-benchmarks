#!/bin/bash
# YAML configuration parser for bash scripts
# Simple parser that handles basic YAML structure

set -e

# Parse YAML file and extract values
# Usage: parse_yaml <yaml_file>
parse_yaml() {
    local yaml_file="$1"
    local prefix="$2"

    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: Config file not found: $yaml_file" >&2
        return 1
    fi

    # Remove comments and blank lines, then process
    sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$yaml_file" | \
    awk -v prefix="$prefix" '
    BEGIN {
        indent_stack[0] = 0
        level = 0
    }
    {
        # Count leading spaces
        match($0, /^[[:space:]]*/)
        indent = RLENGTH

        # Remove leading spaces
        sub(/^[[:space:]]*/, "")

        # Skip if empty
        if (length($0) == 0) next

        # Handle list items
        if ($0 ~ /^-[[:space:]]/) {
            sub(/^-[[:space:]]*/, "")
            is_list = 1
        } else {
            is_list = 0
        }

        # Handle key: value pairs
        if ($0 ~ /:/) {
            split($0, kv, /:[[:space:]]*/)
            key = kv[1]
            value = kv[2]

            # Remove quotes from value
            gsub(/^["'\''"]|["'\''"']$/, "", value)

            if (prefix != "") {
                key = prefix "_" key
            }

            # Convert to uppercase and replace spaces/dashes with underscores
            key = toupper(key)
            gsub(/[[:space:]-]/, "_", key)

            # Only output if value is not empty (not a nested structure)
            if (length(value) > 0) {
                print key "=\"" value "\""
            }
        }
    }
    '
}

# Get config value
# Usage: get_config_value <yaml_file> <key_path>
get_config_value() {
    local yaml_file="$1"
    local key_path="$2"

    parse_yaml "$yaml_file" | grep "^${key_path}=" | cut -d= -f2- | tr -d '"'
}

# Load default models from config
# Usage: load_default_models <config_file>
# Returns: Array of model paths, one per line
load_default_models() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Config file not found: $config_file" >&2
        return 1
    fi

    # Extract model paths from default_models section
    awk '
    /^default_models:/ { in_section = 1; next }
    /^[a-z_]+:/ && in_section { in_section = 0 }
    in_section && /path:/ {
        # Extract the path value
        match($0, /path:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") {
            print arr[1]
        }
    }
    ' "$config_file"
}

# Load default model names from config
# Usage: load_default_model_names <config_file>
# Returns: Array of model names, one per line
load_default_model_names() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Config file not found: $config_file" >&2
        return 1
    fi

    # Extract model names from default_models section
    awk '
    /^default_models:/ { in_section = 1; next }
    /^[a-z_]+:/ && in_section { in_section = 0 }
    in_section && /name:/ {
        # Extract the name value
        match($0, /name:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") {
            print arr[1]
        }
    }
    ' "$config_file"
}

# Export as functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f parse_yaml
    export -f get_config_value
    export -f load_default_models
    export -f load_default_model_names
fi
