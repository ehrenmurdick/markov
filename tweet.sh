#!/bin/sh

eval "$(rbenv init -)"

touch error.log
/Users/pivotal/.rbenv/versions/2.3.1/bin/t update "`/usr/bin/env ruby markov.rb melvile.sqlite generate 2>>error.log`" 2>>error.log
