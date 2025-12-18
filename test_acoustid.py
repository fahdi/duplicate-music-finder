#!/usr/bin/env python3
"""
Test script to verify AcoustID matches for songs in a folder.
Uses POST request to handle long fingerprints properly.
"""

import subprocess
import json
import urllib.request
import urllib.parse
import sys
import os

API_KEY = "RsAFCdlGZU"
FPCALC = "/usr/local/bin/fpcalc"

def get_fingerprint(filepath):
    """Generate fingerprint using fpcalc"""
    try:
        result = subprocess.run(
            [FPCALC, "-json", filepath],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            return None, None
        data = json.loads(result.stdout)
        return data.get("fingerprint"), int(data.get("duration", 0))
    except Exception as e:
        print(f"  Error: {e}")
        return None, None

def lookup_acoustid(fingerprint, duration):
    """Query AcoustID API using POST"""
    url = "https://api.acoustid.org/v2/lookup"
    data = urllib.parse.urlencode({
        "client": API_KEY,
        "fingerprint": fingerprint,
        "duration": duration,
        "meta": "recordings+releasegroups"
    }).encode()
    
    try:
        req = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        return {"status": "error", "error": str(e)}

def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "/Volumes/Stuff/Dropbox/ghazals"
    
    print("=" * 60)
    print("AcoustID Test Script (Python)")
    print(f"Folder: {folder}")
    print("=" * 60)
    print()
    
    audio_extensions = ('.mp3', '.m4a', '.wav', '.flac', '.aac')
    files = [f for f in os.listdir(folder) if f.lower().endswith(audio_extensions)]
    
    matched = 0
    total = 0
    
    for filename in files:
        filepath = os.path.join(folder, filename)
        print("-" * 60)
        print(f"File: {filename}")
        
        # Get fingerprint
        fingerprint, duration = get_fingerprint(filepath)
        if not fingerprint:
            print("  ❌ Failed to generate fingerprint")
            continue
        
        total += 1
        print(f"  Duration: {duration}s")
        print(f"  Fingerprint: {fingerprint[:50]}...")
        
        # Query AcoustID
        result = lookup_acoustid(fingerprint, duration)
        
        if result.get("status") != "ok":
            print(f"  ❌ API Error: {result.get('error', 'Unknown')}")
            continue
        
        # Check results
        results = result.get("results", [])
        if results and results[0].get("score", 0) > 0:
            best = results[0]
            score = best.get("score", 0)
            
            # Get recording info
            recordings = best.get("recordings", [])
            if recordings:
                rec = recordings[0]
                title = rec.get("title", "Unknown")
                artists = ", ".join(a.get("name", "") for a in rec.get("artists", []))
                print(f"  ✅ MATCH FOUND!")
                print(f"     Score: {score:.0%}")
                print(f"     Title: {title}")
                print(f"     Artist: {artists}")
                matched += 1
            else:
                print(f"  🟡 Match found (score: {score:.0%}) but no recording info")
        else:
            print("  ❌ No matches in AcoustID database")
    
    print()
    print("=" * 60)
    print(f"Results: {matched}/{total} tracks matched")
    print("=" * 60)

if __name__ == "__main__":
    main()
