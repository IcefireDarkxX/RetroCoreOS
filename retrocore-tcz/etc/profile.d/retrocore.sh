#!/bin/sh
if [ -t 1 ] && command -v retrocore-info >/dev/null 2>&1; then
  retrocore-info --banner
fi
