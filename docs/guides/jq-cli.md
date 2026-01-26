---
name: "jq-cli-guide"
displayName: "jq CLI Guide"
description: "Complete guide for using jq command-line JSON processor with common workflows, filters, and troubleshooting tips."
keywords: ["jq", "json", "cli", "filter", "parse"]
author: "CloudToLocalLLM Team"
---

# jq CLI Guide

## Overview

jq is a lightweight and flexible command-line JSON processor that allows you to slice, filter, map, and transform structured data with ease. It's like sed for JSON data - you can use it to extract specific values, transform data structures, and perform complex queries on JSON files or streams.

Whether you're working with API responses, configuration files, or log data, jq provides a powerful query language that makes JSON manipulation simple and efficient. This guide covers installation, common workflows, and practical examples to get you productive with jq quickly.

## Onboarding

### Installation

#### Via Package Managers

```bash
# macOS (Homebrew)
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL/Fedora
sudo yum install jq
# or
sudo dnf install jq

# Windows (Chocolatey)
choco install jq

# Windows (Scoop)
scoop install jq
```

#### Manual Installation

1. Download the appropriate binary from [jq releases](https://github.com/stedolan/jq/releases)
2. Place the binary in your PATH
3. Make it executable (Linux/macOS): `chmod +x jq`

### Prerequisites

- No special requirements - jq is a standalone binary
- Works on Linux, macOS, and Windows
- Compatible with any JSON data source

### Verification

```bash
# Verify installation
jq --version

# Expected output:
jq-1.6 (or newer version)

# Test basic functionality
echo '{"name": "test"}' | jq '.'
# Expected output:
{
  "name": "test"
}
```

## Common Workflows

### Workflow: Extract Specific Fields

**Goal:** Extract specific values from JSON objects

**Commands:**

```bash
# Extract a single field
echo '{"name": "John", "age": 30}' | jq '.name'

# Extract multiple fields
echo '{"name": "John", "age": 30, "city": "NYC"}' | jq '.name, .age'

# Extract nested fields
echo '{"user": {"name": "John", "profile": {"age": 30}}}' | jq '.user.profile.age'
```

**Complete Example:**

```bash
# Sample API response
curl -s https://api.github.com/users/octocat | jq '.name, .public_repos, .followers'

# Output:
"The Octocat"
8
9999
```

### Workflow: Filter Arrays

**Goal:** Filter and process JSON arrays

**Commands:**

```bash
# Filter array elements
echo '[{"name": "John", "age": 30}, {"name": "Jane", "age": 25}]' | jq '.[] | select(.age > 27)'

# Map over array elements
echo '[1, 2, 3, 4]' | jq 'map(. * 2)'

# Get array length
echo '[1, 2, 3, 4]' | jq 'length'
```

**Complete Example:**

```bash
# Filter GitHub repositories by language
curl -s https://api.github.com/users/octocat/repos | jq '.[] | select(.language == "JavaScript") | .name'
```

### Workflow: Transform Data Structure

**Goal:** Reshape JSON data into new formats

**Commands:**

```bash
# Create new object structure
echo '{"first": "John", "last": "Doe"}' | jq '{fullName: (.first + " " + .last)}'

# Group array elements
echo '[{"type": "A", "value": 1}, {"type": "B", "value": 2}, {"type": "A", "value": 3}]' | jq 'group_by(.type)'

# Convert array to object
echo '[{"key": "name", "value": "John"}, {"key": "age", "value": 30}]' | jq 'from_entries'
```

## Command Reference

### Basic Filters

**Purpose:** Core jq operations for data access and manipulation

**Syntax:**

```bash
jq 'filter' [file.json]
```

**Common Filters:**
| Filter | Description | Example |
|--------|-------------|---------|
| `.` | Identity (pretty-print) | `jq '.'` |
| `.field` | Access field | `jq '.name'` |
| `.[]` | Array/object iterator | `jq '.[]'` |
| `.[n]` | Array index access | `jq '.[0]'` |
| `.field?` | Optional field access | `jq '.missing?'` |

**Examples:**

```bash
# Pretty-print JSON
echo '{"name":"John","age":30}' | jq '.'

# Access nested field safely
echo '{"user": {"name": "John"}}' | jq '.user.name?'
```

### Array Operations

**Purpose:** Working with JSON arrays

| Operation | Description | Example |
|-----------|-------------|---------|
| `map(expr)` | Transform each element | `jq 'map(. * 2)'` |
| `select(expr)` | Filter elements | `jq '.[] \| select(.age > 25)'` |
| `sort` | Sort array | `jq 'sort'` |
| `sort_by(expr)` | Sort by expression | `jq 'sort_by(.age)'` |
| `group_by(expr)` | Group elements | `jq 'group_by(.type)'` |
| `unique` | Remove duplicates | `jq 'unique'` |

**Examples:**

```bash
# Sort users by age
echo '[{"name": "John", "age": 30}, {"name": "Jane", "age": 25}]' | jq 'sort_by(.age)'

# Get unique values
echo '[1, 2, 2, 3, 3, 3]' | jq 'unique'
```

### String Operations

**Purpose:** Manipulating string values

| Operation | Description | Example |
|-----------|-------------|---------|
| `length` | String/array length | `jq '.name \| length'` |
| `split(sep)` | Split string | `jq 'split(",")'` |
| `join(sep)` | Join array | `jq 'join(", ")'` |
| `startswith(str)` | Check prefix | `jq 'startswith("prefix")'` |
| `contains(str)` | Check substring | `jq 'contains("sub")'` |
| `test(regex)` | Regex match | `jq 'test("^[0-9]+$")'` |

## Troubleshooting

### Error: "parse error: Invalid numeric literal"

**Cause:** Malformed JSON input
**Solution:**

1. Validate JSON syntax: `echo 'your-json' | jq '.'`
2. Check for trailing commas, missing quotes, or unescaped characters
3. Use `jq -R` for raw string input if not JSON

### Error: "jq: command not found"

**Cause:** jq not installed or not in PATH
**Solution:**

1. Install jq using package manager
2. Verify installation: `which jq`
3. Add jq binary location to PATH if needed

### Error: "Cannot index string with string"

**Cause:** Trying to access object field on a string value
**Solution:**

1. Check data structure: `jq 'type'`
2. Use optional access: `.field?`
3. Add type checking: `if type == "object" then .field else empty end`

### Empty Output When Expected Results

**Cause:** Filter doesn't match data structure
**Solution:**

1. Inspect data structure: `jq '.'`
2. Check field names and types: `jq 'keys'`
3. Use debug output: `jq --arg debug true '.'`

### Performance Issues with Large Files

**Cause:** Loading entire file into memory
**Solution:**

1. Use streaming parser: `jq --stream`
2. Process line by line: `jq -c '.[]'`
3. Filter early: `jq '.[] | select(.important)'`

## Best Practices

- **Use `.field?` for optional access** - Prevents errors when fields might be missing
- **Pipe operations for readability** - Chain filters with `|` for complex transformations
- **Test filters incrementally** - Build complex queries step by step
- **Use `--raw-output` for clean strings** - Remove JSON quotes from string output
- **Validate JSON first** - Always check input format before complex operations
- **Use `--compact-output` for minimal JSON** - Reduce output size for large datasets
- **Leverage `--slurp` for multiple inputs** - Combine multiple JSON inputs into array

## Additional Resources

- Official Documentation: https://stedolan.github.io/jq/
- GitHub Repository: https://github.com/stedolan/jq
- Interactive Tutorial: https://jqplay.org/
- Manual: https://stedolan.github.io/jq/manual/

---

**CLI Tool:** `jq`
**Installation:** `brew install jq` (macOS) or package manager of choice
