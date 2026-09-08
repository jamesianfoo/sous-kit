function main(input)
{
    var lines = input.trim().split("\n");
    var arr = lines[1].trim().split(/\s+/);
    for (var i = 0; i < arr.length; i++) arr[i] = arr[i] - 0;
    var t = lines[2] - 0;
    var cnt = {};
    for (var i = 0; i < arr.length; i++) cnt[arr[i]] = (cnt[arr[i]] || 0) + 1;
    var answer = 0;
    for (var key in cnt) {
        var x = key - 0;
        var y = t - x;
        if (x < y && cnt[y]) answer += cnt[x] * cnt[y];        // count each pair once
        else if (x === y) answer += cnt[x] * (cnt[x] - 1) / 2; // x pairs with another x
    }
    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
