#!/bin/bash
# Claude Code Statusline: Model | ███████  49% mcp:4 +1k -23 [2h|↓1.2m↑0.3m|$12]
R=$'\e[0m' CD=~/.claude/statusline-cache
{ read -r M; read -r W; read -r S; read -r Z; read -r I; read -r C; read -r B
read -r K; read -r D; read -r A; read -r X; read -r TI; read -r TO; } < <(jq -r '
.model.display_name,.workspace.current_dir,(.session_id//""),(.context_window.context_window_size//200000),
(.context_window.current_usage|(.input_tokens//0),(.cache_creation_input_tokens//0),(.cache_read_input_tokens//0)),
(.cost|(.total_cost_usd//0),(.total_duration_ms//0),(.total_lines_added//0),(.total_lines_removed//0)),
(.context_window|(.total_input_tokens//0),(.total_output_tokens//0))')
N=$((I+C)) T=$((B+N)) P=$((Z>0?T*100/Z:0)) IC=0
[[ -n $S && $B -gt 0 ]] && { mkdir -p "$CD"; F="$CD/$S"; [[ -f $F ]] && IC=$(<"$F") || { echo "$B">"$F"; IC=$B; find "$CD" -mtime +7 -delete 2>/dev/null& }; ((IC>B)) && IC=$B; }
G=$((B-IC)) MC=0 J="$W/.mcp.json" L="$W/.claude/settings.local.json"
[[ -f $J ]] && { [[ -f $L ]] && MC=$(jq -r '(.enabledMcpjsonServers//[])|length' "$L" 2>/dev/null); [[ $MC == 0 ]] && MC=$(jq -rs '(.[1].disabledMcpjsonServers//[]) as $d|.[0].mcpServers|keys|map(select(. as $k|$d|index($k)|not))|length' "$J" "$L" 2>/dev/null||echo 0); } || MC=$(jq -r '.mcpServers|keys|length' "$J" 2>/dev/null||echo 0)
BW=15 IW=$((Z>0?IC*BW/Z:0)) GW=$((Z>0?G*BW/Z:0)) MW=$((Z>0?N*BW/Z:0)); ((IC>0&&IW==0))&&IW=1;((G>0&&GW==0))&&GW=1;((N>0&&MW==0))&&MW=1
BAR="";for((i=0;i<IW&&i<BW-1;i++));do BAR+=$'\e[38;5;30m█'$R;done;for((i=0;i<GW&&IW+i<BW-1;i++));do BAR+=$'\e[38;5;73m█'$R;done
for((i=0;i<MW&&IW+GW+i<BW-1;i++));do BAR+=$'\e[38;5;116m█'$R;done;p=$((IW+GW+MW));while((p<BW-1));do BAR+=" ";((p++));done;BAR+=$'\e[38;5;167m│'$R
O=$'\e[38;5;73m'"$M"$R$' \e[38;5;102m|\e[0m '"$BAR $P%"; ((MC>0))&&O+=$' \e[38;5;109mmcp:'$MC$R
k(){ ((${1}>999))&&printf "%d.%dk" $(($1/1000)) $((($1%1000)/100))||echo $1; }; ((A>0||X>0))&&O+=$' \e[38;5;33m+'$(k $A)$R$' \e[38;5;208m-'$(k $X)$R
[[ $K != 0 ]]&&O+=$' \e[38;5;102m['$((D/3600000))'h|'$R$' \e[38;5;102m↓'$(printf "%d.%d" $((TI/1000000)) $(((TI%1000000)/100000)))m$R$' \e[38;5;179m↑'$(printf "%d.%d" $((TO/1000000)) $(((TO%1000000)/100000)))m$R$' \e[38;5;102m|$'${K%.*}]$R
echo -e "$O"
