#!/bin/bash
# All Trade Commercial — add job photos to the website gallery.
#
# Usage:
#   1. Put photos (JPG/PNG/HEIC, any size) into ~/Desktop/atc-photos
#   2. Run: ./scripts/add-photos.sh        (or double-click "Add Site Photos.command")
#   3. Photos are resized, added to the gallery (newest first), committed, and pushed live.
#
# The gallery shows the 12 most recent work photos. Older ones stay in the repo.

set -euo pipefail
SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DROP_DIR="$HOME/Desktop/atc-photos"
WORK_DIR="$SITE_DIR/assets/photos/work"
INDEX="$SITE_DIR/index.html"
MAX_GALLERY=12

mkdir -p "$WORK_DIR" "$DROP_DIR"

shopt -s nullglob nocaseglob
new_files=("$DROP_DIR"/*.{jpg,jpeg,png,heic})
shopt -u nocaseglob

count=0
for f in "${new_files[@]}"; do
  stamp="$(date +%Y%m%d-%H%M%S)-$count"
  out="$WORK_DIR/job-$stamp.jpg"
  # resize to max 1400px on the long edge, convert to jpg, strip huge phone originals
  sips -s format jpeg -s formatOptions 75 -Z 1400 "$f" --out "$out" >/dev/null
  rm "$f"
  count=$((count+1))
  echo "added: $(basename "$out")"
done

if [ "$count" -eq 0 ] && [ -z "$(ls -A "$WORK_DIR" 2>/dev/null)" ]; then
  echo "No photos found in $DROP_DIR and no existing work photos — nothing to do."
  exit 0
fi

# Rebuild the gallery block from work photos (newest first), if any exist
work_photos=$(ls -t "$WORK_DIR"/*.jpg 2>/dev/null | head -$MAX_GALLERY || true)
if [ -n "$work_photos" ]; then
  tags=""
  while IFS= read -r p; do
    rel="/assets/photos/work/$(basename "$p")"
    tags="$tags        <img src=\"$rel\" alt=\"Commercial plumbing and handyman services\" loading=\"lazy\" />\n"
  done <<< "$work_photos"

  python3 - "$INDEX" "$tags" << 'PYEOF'
import re, sys
index_path, tags = sys.argv[1], sys.argv[2].replace('\\n', '\n')
html = open(index_path).read()
new = re.sub(
    r'(<!-- GALLERY:START[^>]*-->).*?(<!-- GALLERY:END -->)',
    lambda m: m.group(1) + '\n' + tags + '        ' + m.group(2),
    html, flags=re.S)
open(index_path, 'w').write(new)
print("gallery updated")
PYEOF
fi

cd "$SITE_DIR"
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "Nothing changed."
  exit 0
fi
git add -A
git commit -m "Add job photos to gallery" >/dev/null
git push >/dev/null
echo ""
echo "✅ Done — $count new photo(s) pushed. Live at https://alltradecommercial.com in ~2 minutes."
