#!/bin/bash

for i in `cat $1 | grep 'a id=' | cut -d "'" -f 2`
do
  scp media/$i.jpg rocketscie@mudasobwa.ru:/home/r/rocketscie/meme-me/public_html/assets/media/
done
