#!/bin/bash
set -e

# Flutter Architecture Validator
# Validates that a Flutter project follows the layered architecture pattern

echo "Validating Flutter project architecture..." >&2

PROJECT_DIR="${1:-.}"

if [ ! -f "$PROJECT_DIR/pubspec.yaml" ]; then
    echo "Error: No pubspec.yaml found in $PROJECT_DIR" >&2
    exit 1
fi

ERRORS=0

# Check directory structure exists
check_dir() {
    local dir="$1"
    local name="$2"
    if [ ! -d "$PROJECT_DIR/$dir" ]; then
        echo "WARNING: Missing $name directory: $dir" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

check_dir "lib/data" "Data layer"
check_dir "lib/domain" "Domain layer"
check_dir "lib/ui" "UI layer"
check_dir "lib/ui/core" "Shared UI components"
check_dir "lib/ui/features" "Feature modules"

# Check for anti-patterns in dart files
echo "Scanning for architectural violations..." >&2

# Look for direct HTTP calls in UI/ViewModels
if grep -r "http\|dio\|httpClient" "$PROJECT_DIR/lib/ui" --include="*.dart" -l 2>/dev/null; then
    echo "WARNING: Direct HTTP usage found in UI layer. Move to Services." >&2
    ERRORS=$((ERRORS + 1))
fi

# Look for ChangeNotifier in data layer
if grep -r "ChangeNotifier\|ValueNotifier" "$PROJECT_DIR/lib/data" --include="*.dart" -l 2>/dev/null; then
    echo "WARNING: State management found in Data layer. Move to ViewModels." >&2
    ERRORS=$((ERRORS + 1))
fi

# Count layer distribution
DATA_FILES=$(find "$PROJECT_DIR/lib/data" -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
DOMAIN_FILES=$(find "$PROJECT_DIR/lib/domain" -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
UI_FILES=$(find "$PROJECT_DIR/lib/ui" -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')

echo "Layer distribution: Data=$DATA_FILES, Domain=$DOMAIN_FILES, UI=$UI_FILES" >&2

# Output JSON result
cat <<EOF
{
  "valid": $(if [ $ERRORS -eq 0 ]; then echo "true"; else echo "false"; fi),
  "errors": $ERRORS,
  "layers": {
    "data": $DATA_FILES,
    "domain": $DOMAIN_FILES,
    "ui": $UI_FILES
  }
}
EOF

if [ $ERRORS -eq 0 ]; then
    echo "Architecture validation passed!" >&2
else
    echo "Architecture validation found $ERRORS issue(s)." >&2
fi

exit 0
