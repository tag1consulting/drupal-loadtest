## Configuration:
RANGE=10   # chose from 10 different colors
LOOP=5003  # update favorite color for 5,000 users

###

function random_color {
  J=$RANDOM
  let "J %= $RANGE"
  if [ $J -eq 0 ]
  then
    printf %s "White"
  elif [ $J -eq 1 ]
  then
    printf %s "Red"
  elif [ $J -eq 2 ]
  then
    printf %s "Blue"
  elif [ $J -eq 3 ]
  then
    printf %s "Green"
  elif [ $J -eq 4 ]
  then
    printf %s "Yellow"
  elif [ $J -eq 5 ]
  then
    printf %s "Orange"
  elif [ $J -eq 6 ]
  then
    printf %s "Pink"
  elif [ $J -eq 7 ]
  then
    printf %s "Brown"
  elif [ $J -eq 8 ]
  then
    printf %s "Tan"
  elif [ $J -eq 9 ]
  then
    printf %s "Black"
  fi
}

I=3
while [ $I -lt $LOOP ]
do
  printf %s "mysql -e \"INSERT INTO profile_values VALUES(1, $I, '"
  random_color
  echo "');\" memcache6base"
  let "I += 1"
done
