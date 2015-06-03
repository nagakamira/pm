#!/bin/bash

if [ $# -eq 0 ]; then pan -h; fi

pan -u $@