#!/bin/bash

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "fatal: not in git repo"
    exit 1
fi

trim() {
    leading=$(echo -e "$1" | sed -e 's/^[[:space:]]*//')
    trailing=$(echo -e "$leading" | sed -e 's/[[:space:]]*$//')
    echo "$trailing"
}

tmpfile=$(mktemp /tmp/git-rewrite-all.XXXXXX)
git log --pretty=format:"%cI | %H | %s" >"$tmpfile"

echo "use your arrow keys to move around in the text editor and hit ctrl-x then y to save and exit"
echo "you can safely ignore the second field of the table (the one with numbers and letters; it's a hash)"
echo "make sure you keep the same date format as the one that's in the file"
read -rp "press enter to continue "
nano "$tmpfile" || {
    echo "error: nano not found. run 'sudo apt install nano'."
    exit 1
}

ENV_FILTER=""
MSG_FILTER=""
while read -r commit; do
    IFS="|" read -r date hash msg <<<"$commit"

    date_stripped=$(trim "$date")
    msg_stripped=$(trim "$msg")
    hash_stripped=$(trim "$hash")

    ENV_FILTER="""
        $ENV_FILTER
        if [ \$GIT_COMMIT = \"$hash_stripped\" ]; then
            export GIT_AUTHOR_DATE=\"$date_stripped\"
            export GIT_COMMITTER_DATE=\"$date_stripped\"
        fi
    """
    MSG_FILTER="""
        $MSG_FILTER
        if [ \$GIT_COMMIT = \"$hash_stripped\" ]; then
            echo \"$msg_stripped\"
        fi
    """
done <"$tmpfile"

export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f \
    --env-filter "$ENV_FILTER" \
    --msg-filter "$MSG_FILTER"
