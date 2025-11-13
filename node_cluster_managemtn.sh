#!/bin/bash
 
fzf_opts="--header-first --layout=reverse --border"
 
function request_node() {
  node=$(evrtd ett list \
    | awk 'NR>2 {print}'\
    | fzf $fzf_opts --header "Select a node type") || return
 
  echo "One $node please."
  evrtd request -e $node
}
 
function extend_node() {
  selection=$(evrtd list\
    | awk 'NR>2 {print}'\
    | fzf $fzf_opts --header "Select your node") || return
 
  id=$(echo $selection | awk '{print $2}')
 
  read -p "How many more hours do you think you need? 🐌: " time
  evrtd update --id $id --renew-lease $time
}
 
function list_nodes() {
  evrtd list
}
 
function ssh_node() {
  selection=$(evrtd list\
    | awk 'NR>2 {print}'\
    | fzf $fzf_opts --header "Select your node") || return
 
  id=$(echo $selection | awk '{print $2}')
 
  echo "Selected $id"
 
  node=$(evrtd list --id $id \
    | tr ' ' '\n' | tr ',' ' ' | grep sero \
    | fzf $fzf_opts --header "Select the chassis (normally second option)") || return
 
  echo "Selected for ssh $node"
 
  ssh root@$node
}
 
function release_node() {
  selection=$(evrtd list $1\
    | awk 'NR>2 {print}'\
    | fzf $fzf_opts --header "Select your node") || return
 
  id=$(echo $selection | awk '{print $2}')
 
  echo "Bye bye 👋"
  evrtd release --id $id
}
 
function set_kubeconfig() {
  if [ -z ${KUBECONFIG+x} ];
     then echo "KUBECONFIG is unset. Export it with KUBECONFIG=<path>"; exit 1;
     else echo "KUBECONFIG is set to '$KUBECONFIG'";
  fi
 
  selection=$(evrtd list $1\
    | awk 'NR>2 {print}'\
    | fzf $fzf_opts --header "Select your node") || return
 
  id=$(echo $selection | awk '{print $2}')
 
  evrtd show -i $id cluster-config > $KUBECONFIG
}
 
function steal_kubeconfig() {
  read -p "Hehe. Enter your victim's signum: " signum
 
  set_kubeconfig "-u $signum"
}
 
# flander.sh
 
set -e
export PATH="$PATH:/app/vbuild/RHEL8-x86_64/fzf/0.53.0/bin"
 
opt_request="🙏-Request-a-noderino"
opt_list="📃-List-my-noderinos"
opt_extend="🕑-Extend-my-noderino"
opt_ssh="🔗-SSH-to-noderino"
opt_release="👋-Release-a-noderino"
opt_kubeset="🔧-Set-my-kuberino"
opt_steal="🦖-Steal-a-kuberino"
 
opt=$(echo "$opt_request $opt_list $opt_extend $opt_ssh $opt_release $opt_kubeset $opt_steal"\
  | tr ' ' '\n'\
  | fzf $fzf_opts --header "flander.sh is an EVRTD wrapper. Select an option") || exit 0
 
if [ $opt == $opt_request ]; then
  request_node
elif [ $opt == $opt_extend ]; then
  extend_node
elif [ $opt == $opt_list ]; then
  list_nodes
elif [ $opt == $opt_ssh ]; then
  ssh_node
elif [ $opt == $opt_release ]; then
  release_node
elif [ $opt == $opt_kubeset ]; then
  set_kubeconfig
elif [ $opt == $opt_steal ]; then
  steal_kubeconfig
fi
 
echo "Bye"
