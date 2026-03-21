#!/bin/bash

status=0
for f in tests/test_*.mojo; do
    echo "Running $f..."
    mojo run -I src/ "$f" || status=1
done
exit $status
