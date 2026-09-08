# How to solve HSBC / SHL / AMCAT style coding questions

Every question you have seen so far is the same shape:

1. Read some numbers from the input.
2. Count something, or find pairs of something.
3. Print one number.

If you learn the shape once, every new question is just "which counting trick do I need".

---

## Step 1: Copy the input template first, before you think

The hardest part of these platforms is reading the input, not the algorithm.
Never write it from memory under a timer. Paste it.

JavaScript (Node): `templates/template.js`
C: `templates/template.c`

Both templates already split the input into lines and turn the numbers into
an array. You only fill in the middle.

Rules that bite people:

- `parseInt` and `Number` are sometimes blocked. `x - 0` always works.
- Print with `process.stdout.write("" + answer)` in JS or `printf("%d", answer)` in C.
  No extra words, no extra newline unless the expected output has one.
- Trim the input before splitting. There is often a trailing space.

---

## Step 2: Write the answer for the example by hand

Before writing any code, take the sample input and work out the sample output
with a pencil. If you cannot do it by hand, you cannot code it.

Example: `8 6 14 17 9 3`, K = 5, count pairs with difference 5.

Go through each number and ask "is number + 5 in the list?"

    8 -> 13? no
    6 -> 11? no
    14 -> 19? no
    17 -> 22? no
    9 -> 14? yes   (pair 1)
    3 -> 8?  yes   (pair 2)

Answer 2. Now you know exactly what the loop must do.

---

## Step 3: Pick the pattern

There are only three patterns in this whole family of tests.

### Pattern A: loop and count (one condition per element)

Use when the question is "how many elements are ...".

    count = 0
    for each x in list:
        if condition(x): count = count + 1
    print count

Examples: less than K, even numbers, greater than average, equal to K.

### Pattern B: frequency map (tally sheet)

Use when the question mentions pairs, duplicates, "appears exactly once",
"identical", or "difference of K".

    cnt = {}                          // empty tally sheet
    for each x in list:
        cnt[x] = (cnt[x] or 0) + 1    // add a tick mark under x

Now you can ask questions of the tally sheet in one lookup:

- How many pairs of identical numbers?  sum of  cnt[x] / 2  (whole part)
- How many appear exactly once?         count keys where cnt[x] == 1
- How many pairs differ by K?           for each x, add cnt[x] * cnt[x + K]
- How many pairs sum to T?              for each x < T - x, add cnt[x] * cnt[T - x]

Why a map and not two loops? Two loops compare every element with every
other element. For a million elements that is 500 billion checks and the
platform kills it. The map walks the list once.

### Pattern C: sort first

Use when the question is about order: smallest, largest, second largest,
median, "closest pair".

    list.sort((a, b) => a - b)     // JS needs the comparator or it sorts as text
    // now list[0] is smallest, list[n-1] is largest

---

## Step 4: Handle the two edge cases everyone forgets

- **Duplicates.** Two 3s and one 9 with K = 6 is two pairs, not one.
  That is why Pattern B multiplies counts instead of checking "exists".
- **K = 0.** "Difference of 0" means pairs of equal numbers. Partner is
  the number itself, so use c * (c - 1) / 2, not c * c.

---

## Step 5: Test the example, then test one you made up

Run the sample. Then run an input with duplicates and an input with one
element. If both give sensible answers, submit.

---

## Drill plan

Do one problem a day from `problems/`. Each folder has:

- `problem.md`: the question in the same style as the tests
- `input1.txt`, `expected1.txt` and a second pair: test cases
- `starter.js`: the template with a TODO

Write your solution in `starter.js` and run:

    ./run.sh 01

Only look at `solutions/` after you have made it pass or been stuck 20 minutes.

Order:

    01  count less than K          Pattern A
    02  count even numbers         Pattern A
    03  pairs of identical numbers Pattern B
    04  appears exactly once       Pattern B
    05  pairs with difference K    Pattern B, duplicates
    06  pairs that sum to T        Pattern B, careful about double counting
    07  second largest             Pattern C
    08  string rotation            loops over strings

When you can do 01 to 06 without looking at the guide, you are ready for the
real test.
