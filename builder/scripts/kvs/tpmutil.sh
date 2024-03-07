#!/bin/bash

write_tpm(){
  local index=$1
  local data=$2
  
  tpmc write "$index" "$data"
}

read_tpm(){
  local index=$1
  local bytes=$2
  
  tpmc read "$index" "$bytes"
}
