function main(input)
{
    var lines = input.trim().split("\n");
    var word1 = lines[0].trim();
    var word2 = lines[1].trim();

    var answer = -1;
    // TODO: your logic here

    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";
process.stdin.on("data", function (input) { stdin_input += input; });
process.stdin.on("end", function () { main(stdin_input); });
