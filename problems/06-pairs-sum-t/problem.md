# 06 Pairs that sum to T (Pattern B, avoid double counting)

Print the number of pairs (i, j) with i < j whose values add up to exactly T.

Input: line 1 is N, line 2 is N integers, line 3 is T.

Example
```
6
1 5 7 -1 5 3
6
```
Output: 3  ((1,5), (7,-1), (1,5))

Hint: for each value x, its partner is T - x. Only count when x < T - x, and handle x == T - x with c*(c-1)/2.
