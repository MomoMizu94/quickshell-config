#!/usr/bin/env bash
# Lightweight net up/down sampler for the sidebar's NetSpeedIndicator.
# Same two-sample /proc/net/dev diff as perf.sh's net calc, without the
# cpu/gpu/ram/disk sampling that script also does (irrelevant here, and
# this runs on its own always-on timer rather than only while a tab is open).
n1=$(awk '/:/{gsub(":","",$1); if($1!="lo"){rx+=$2; tx+=$10}} END{print rx+0, tx+0}' /proc/net/dev)
sleep 0.5
n2=$(awk '/:/{gsub(":","",$1); if($1!="lo"){rx+=$2; tx+=$10}} END{print rx+0, tx+0}' /proc/net/dev)
read -r rx1 tx1 <<< "$n1"
read -r rx2 tx2 <<< "$n2"
up=$(awk -v a="$tx1" -v b="$tx2" 'BEGIN{printf "%.1f", (b-a)/0.5/1000000}')
down=$(awk -v a="$rx1" -v b="$rx2" 'BEGIN{printf "%.1f", (b-a)/0.5/1000000}')
printf '{"up":%s,"down":%s}\n' "${up:-0}" "${down:-0}"
