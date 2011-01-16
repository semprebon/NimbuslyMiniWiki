#!/bin/bash

MINIWIKI_HOME=~/Projects/MiniWiki
for f in "$@"
do
    pathless_name=${f##*/}
    basename=${pathless_name%.*}
    jsfile=${f/coffeescript/javascript\/generated}
    jsfile=${jsfile/%\.coffee/\.js}
    if test $f -nt $jsfile
    then
        echo 'converting ' $f ' to ' $jsfile >&2
        java -jar $MINIWIKI_HOME/jcoffeescript-1.0.jar <$f >$jsfile
    fi
done
