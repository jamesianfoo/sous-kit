function main(input)
{
    var lines = input.trim().split("\n");
    var n = lines[0] - 0;
    var arr = lines[1].trim().split(/\s+/);
    for (var i = 0; i < arr.length; i++) arr[i] = arr[i] - 0;
    // If there is a third line with K, uncomment:
    // var k = lines[2] - 0;

    var answer = 0;
    // TODO: your logic here

    process.stdout.write("" + answer);
}

process.stdin.resume();
process.stdin.setEncoding("utf-8");
var stdin_input = "";

process.stdin.on("data", function (input) {
    stdin_input += input;
});

process.stdin.on("end", function () {
    main(stdin_input);
});
