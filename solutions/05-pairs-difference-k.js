function main(input)
{
    var lines = input.trim().split("\n");
    var arr = lines[1].trim().split(/\s+/);
    for (var i = 0; i < arr.length; i++) arr[i] = arr[i] - 0;
    var k = lines[2] - 0;
    var cnt = {};
    for (var i = 0; i < arr.length; i++) cnt[arr[i]] = (cnt[arr[i]] || 0) + 1;
    var answer = 0;
    for (var key in cnt) {
        var c = cnt[key];
        if (k === 0) {
            answer += c * (c - 1) / 2;       // partner is itself: choose 2 of c copies
        } else {
            var partner = (key - 0) + k;     // keys are strings, so convert back
            if (cnt[partner]) answer += c * cnt[partner];   // every copy pairs with every copy
        }
    }
    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
