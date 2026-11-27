#!/bin/sh

SHARED_DIR="/shared"
LOCK_FILE="$SHARED_DIR/.lock"

ID=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')

counter=1

mkdir -p "$SHARED_DIR"

exec 200>"$LOCK_FILE"

create_file() {
    i=1
    while :; do
        name=$(printf "%03d" "$i")
        file="$SHARED_DIR/$name"
        if [ ! -e "$file" ]; then
            printf "%s %d\n" "$ID" "$counter" > "$file"
            echo "$file"
            return 0
        fi
        i=$((i + 1))
    done
}


while :; do

    flock -x 200
    file=$(create_file)
    flock -u 200

    counter=$((counter + 1))
    sleep 1

    rm -f "$file"
    sleep 1
done