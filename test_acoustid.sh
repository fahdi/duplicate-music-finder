#!/bin/bash
# Test script to verify AcoustID matches for songs in a folder
# Usage: ./test_acoustid.sh /path/to/folder

FOLDER="${1:-/Volumes/Stuff/Dropbox/ghazals}"
API_KEY="RsAFCdlGZU"
FPCALC="/usr/local/bin/fpcalc"

echo "========================================"
echo "AcoustID Test Script"
echo "Folder: $FOLDER"
echo "========================================"
echo ""

# Check if fpcalc exists
if [ ! -f "$FPCALC" ]; then
    echo "❌ fpcalc not found at $FPCALC"
    exit 1
fi

# Process each audio file
find "$FOLDER" -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.wav" -o -iname "*.flac" \) | head -10 | while read -r file; do
    echo "----------------------------------------"
    echo "File: $(basename "$file")"
    
    # Generate fingerprint
    RESULT=$("$FPCALC" -json "$file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ Failed to generate fingerprint"
        continue
    fi
    
    FINGERPRINT=$(echo "$RESULT" | grep -o '"fingerprint":"[^"]*"' | cut -d'"' -f4)
    DURATION=$(echo "$RESULT" | grep -o '"duration":[0-9.]*' | cut -d':' -f2 | cut -d'.' -f1)
    
    if [ -z "$FINGERPRINT" ]; then
        echo "❌ No fingerprint generated"
        continue
    fi
    
    echo "Duration: ${DURATION}s"
    echo "Fingerprint: ${FINGERPRINT:0:50}..."
    
    # Query AcoustID
    RESPONSE=$(curl -s "https://api.acoustid.org/v2/lookup?client=$API_KEY&duration=$DURATION&fingerprint=$FINGERPRINT&meta=recordings+releasegroups")
    
    # Check for matches
    STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$STATUS" != "ok" ]; then
        echo "❌ API Error: $STATUS"
        continue
    fi
    
    # Check if results array has any entries
    RESULTS_COUNT=$(echo "$RESPONSE" | grep -o '"results":\[' | wc -l)
    HAS_SCORE=$(echo "$RESPONSE" | grep -o '"score":[0-9.]*' | head -1)
    
    if [ -n "$HAS_SCORE" ]; then
        SCORE=$(echo "$HAS_SCORE" | cut -d':' -f2)
        TITLE=$(echo "$RESPONSE" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "✅ MATCH FOUND!"
        echo "   Score: $SCORE"
        echo "   Title: $TITLE"
    else
        echo "❌ No matches in AcoustID database"
    fi
    
    echo ""
done

echo "========================================"
echo "Test complete!"
echo "========================================"
