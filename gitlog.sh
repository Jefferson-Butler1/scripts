#!/bin/bash

# Configuration - modify these variables
MONTH="11"
YEAR="2024"
AUTHOR="Jefferson-Butler1"

MONTH=$(printf "%02d" $MONTH)

START_DATE="$YEAR-$MONTH-01"
if [ "$MONTH" -eq 12 ]; then
    END_DATE="$((YEAR + 1))-01-01"
else
    NEXT_MONTH=$(printf "%02d" $((10#$MONTH + 1)))
    END_DATE="$YEAR-$NEXT_MONTH-01"
fi

#header
echo "title = \"Git Worklog\""
echo "period = \"$MONTH/$YEAR\""
echo "author = \"$AUTHOR\""
echo ""
echo "[[commits]]"

#commits
git for-each-ref --format='%(refname:short)' refs/heads/ | while read branch; do
    git log --author="$AUTHOR" --first-parent --reverse \
        --since="$START_DATE" --until="$END_DATE" \
        --format="%ad %h $branch %s" \
        --date=short $branch
done | uniq | while read -r line; do
    date=$(echo "$line" | cut -d' ' -f1)
    hash=$(echo "$line" | cut -d' ' -f2)
    branch=$(echo "$line" | cut -d' ' -f3)
    message=$(echo "$line" | cut -d' ' -f4-)
    echo "date = \"$date\""
    echo "hash = \"$hash\""
    echo "branch = \"$branch\""
    echo "message = \"$message\""
    echo ""
    echo "[[commits]]"
    #remove trailing [[commits]]
done | sed '$d'
