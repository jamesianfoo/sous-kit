function main(input)
{
    var lines = input.trim().split("\n");
    var w1 = lines[0].trim();
    var w2 = lines[1].trim();
    var n = w1.length;
    var answer = -1;
    if (n === w2.length) {
        for (var start = 0; start < n; start++) {        // try every starting letter
            var j = 0;
            while (j < n && w1[(start + j) % n] === w2[j]) j++;   // % n wraps around the circle
            if (j === n) { answer = 1; break; }
        }
    }
    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
