#include <stdio.h>

int main()
{
    int n, i;
    scanf("%d", &n);
    long long arr[1000000];
    for (i = 0; i < n; i++) scanf("%lld", &arr[i]);
    /* If there is a third line with K, uncomment:
    long long k;
    scanf("%lld", &k);
    */

    long long answer = 0;
    /* TODO: your logic here */

    printf("%lld", answer);
    return 0;
}
