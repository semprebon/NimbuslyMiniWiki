#!/bin/bash

MINIWIKI_HOME=~/Projects/MiniWiki
date >$MINIWIKI_HOME/coffeescript.log
$MINIWIKI_HOME/cf.sh $MINIWIKI_HOME/coffeescript/*.coffee
$MINIWIKI_HOME/cf.sh $MINIWIKI_HOME/uitest/coffeescript/*.coffee
