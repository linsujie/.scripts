#!/bin/bash

read word
word=${word// /_}
google-chrome http://en.wikipedia.org/wiki/$word &
