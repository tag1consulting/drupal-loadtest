## Configuration:
RANGE=10000 # test data includes nids 1 through 10,000
LOOP=2500   # generate 2,500 lines in node.csv, 16 nodes per line

###

function random {
  J=0
  while [ $J -lt 15 ]
  do
    number=$RANDOM
    let "number %= $RANGE"
    printf '"%s"' $number
    if [ $J -ne 14 ]
    then
      printf %s ","
    else
      echo
    fi
    let "J += 1"
  done
}

I=0
while [ $I -lt $LOOP ]
do
  random
  let "I += 1"
done
