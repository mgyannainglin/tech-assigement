if [ "$#" -lt 2 ]; then
    echo "Please input at least two numbers!"
    exit 1;
fi
max=0;
secondMax=0;
for number in "$@"
do
    echo "$number";
    if [ "$number" -gt $max ]; then
        max=$number
    fi
done

for number in "$@"
do
    if [ "$number" -lt $max ] && [ "$number" -gt $secondMax ] ; then
        secondMax=$number
    fi
done

echo "second largest number is $secondMax";

