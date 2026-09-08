function main(input)
{
    var lines = input.trim().split("\n");
    var arr = lines[1].trim().split(/\s+/);
    for (var i = 0; i < arr.length; i++) arr[i] = arr[i] - 0;
    var k = lines[2] - 0;
    var answer = 0;
    for (var i = 0; i < arr.length; i++) {
        if (arr[i] < k) answer++;           // Pattern A: one check per element
    }
    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
