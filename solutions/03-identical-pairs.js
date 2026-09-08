function main(input)
{
    var lines = input.trim().split("\n");
    var arr = lines[1].trim().split(/\s+/);
    for (var i = 0; i < arr.length; i++) arr[i] = arr[i] - 0;
    var cnt = {};                            // Pattern B: tally sheet
    for (var i = 0; i < arr.length; i++) cnt[arr[i]] = (cnt[arr[i]] || 0) + 1;
    var pairs = 0;
    for (var key in cnt) pairs += Math.floor(cnt[key] / 2);   // 3 copies = 1 pair + 1 left
    var remaining = arr.length - 2 * pairs;
    process.stdout.write(pairs + " " + remaining);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
