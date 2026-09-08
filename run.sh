#!/bin/bash
# Usage: ./run.sh 01        runs your starter.js for problem 01
#        ./run.sh 01 sol    runs the reference solution instead
cd "$(dirname "$0")"
dir=$(ls -d problems/$1-* 2>/dev/null | head -1)
if [ -z "$dir" ]; then echo "No problem $1"; exit 1; fi
if [ "$2" = "sol" ]; then prog="solutions/$(basename $dir).js"; else prog="$dir/starter.js"; fi
pass=0; total=0
for inp in $dir/input*.txt; do
  num=$(basename $inp .txt); num=${num#input}
  exp=$(cat $dir/expected$num.txt)
  got=$(node $prog < $inp)
  total=$((total+1))
  if [ "$got" = "$exp" ]; then echo "test $num: PASS"; pass=$((pass+1));
  else echo "test $num: FAIL  expected '$exp' got '$got'"; fi
done
echo "$pass / $total passed"
