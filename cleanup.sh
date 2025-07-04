#!/bin/bash
echo "🧹 Cleaning up repository files..."

# Files to remove
FILES_TO_DELETE=(
    "nginx/.DS_Store"
    "terraform/aws-resou"
    "Jenkinsfile"
)

# Check if files exist and remove them
for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        echo "🗑️  Removing: $file"
        rm "$file"
        git rm "$file" 2>/dev/null || echo "   (File not tracked in git)"
    elif [ -d "$file" ]; then
        echo "🗑️  Removing directory: $file"
        rm -rf "$file"
        git rm -r "$file" 2>/dev/null || echo "   (Directory not tracked in git)"
    else
        echo "❌ File not found: $file"
    fi
done

# Look for other .DS_Store files
echo -e "\n🔍 Checking for other .DS_Store files..."
find . -name ".DS_Store" -type f | while read -r dsfile; do
    echo "🗑️  Found and removing: $dsfile"
    rm "$dsfile"
    git rm "$dsfile" 2>/dev/null || echo "   (File not tracked in git)"
done

# Look for other temporary/incomplete files
echo -e "\n🔍 Checking for other potential cleanup candidates..."
find . -name "*.tmp" -o -name "*.temp" -o -name "*~" -o -name "*.bak" | while read -r tmpfile; do
    echo "🗑️  Found temporary file: $tmpfile"
    echo "   Run: rm \"$tmpfile\" to remove"
done

# Update .gitignore to prevent these files in the future
echo -e "\n📝 Updating .gitignore..."
if ! grep -q "\.DS_Store" .gitignore; then
    echo -e "\n# macOS system files\n.DS_Store\n.DS_Store?" >> .gitignore
    echo "✅ Added .DS_Store to .gitignore"
fi

if ! grep -q "aws-resou" .gitignore; then
    echo -e "\n# Terraform temporary files\nterraform/aws-resou*" >> .gitignore
    echo "✅ Added aws-resou* pattern to .gitignore"
fi

# Show git status
echo -e "\n📊 Git status after cleanup:"
git status --porcelain

echo -e "\n✅ Cleanup completed!"
echo "📋 Next steps:"
echo "   1. Review the changes: git status"
echo "   2. Commit the cleanup: git add -A && git commit -m 'Clean up unnecessary files'"
echo "   3. Push changes: git push origin main"
